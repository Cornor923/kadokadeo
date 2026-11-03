<?php

namespace App\Services;

use App\Enums\ClanActionType;
use App\Enums\ClanAttackStatus;
use App\Events\UserCountersChanged;
use App\Exceptions\ClanException;
use App\Models\Clan;
use App\Models\ClanAction;
use App\Models\ClanAttack;
use App\Models\ClanMission;
use App\Models\ClanMissionStep;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use App\Settings\ClanSettings;
use App\Support\Realtime;

// a clan run is a normal run (contract, rankings): the player asks for it on the clan pages (ClanAction), then the run he
// begins on its page (/clans/play/{action}: the game sends the action, pageAction, no time limit), or else the next run he
// begins on the game, is bound to it, and its score is used when it ends. A mission step is free and unlimited, an attack or a defense
// costs one of the attack games of the day (App\Settings\ClanSettings), then a paid clan game (RunController::begin). The
// games of the day of the normal runs are not used.
class ClanRunService
{
    public function __construct(
        private readonly ClanWarService $warService,
        private readonly ClanMissionService $missionService,
    ) {}

    // "Rejouer" on the page of a clan run: the same clan run again while its target is open (the step not completed yet,
    // the attack still waiting for a defense: improved by the new run), null when the next run would be a normal one
    public function again(ClanAction $action): ?ClanAction
    {
        $user = $action->user;

        // a mission step completed meanwhile (by the player or another member) or a mission over: the reason is given to
        // the page (ClanMissionService::startStep), which sends the player back to the missions. (The action of the page
        // may not be the one of the run that ended: pageAction)
        if ($action->type === ClanActionType::MISSION) {
            // (the run begun meanwhile already went on with the step: continueFailedStep)
            return ClanAction::query()
                ->where('user_id', $action->user_id)
                ->where('clan_mission_step_id', $action->clan_mission_step_id)
                ->where('id', '>', $action->id)
                ->whereNull('completed_at')
                ->latest('id')
                ->first()
                ?? $this->missionService->startStep($user, $action->missionStep);
        }
        if ($action->completed_at === null) {
            return null;
        }

        try {
            return match ($action->type) {
                ClanActionType::DEFENSE => $this->warService->startDefense($user, $action->attack),
                ClanActionType::ATTACK => ($attack = $action->attack ?? ClanAttack::query()->where('run_id', $action->run_id)->first())
                    && $attack->status === ClanAttackStatus::ACTIVE
                    ? $this->warService->startImprovement($user, $attack)
                    : null,
            };
        } catch (ClanException) {
            return null;
        }
    }

    // the clan runs begun by the player and never ended (the page closed during the run...): the new attacks, which block his
    // next attacks and his defenses until they end or are cancelled (ClanWarService::runningAttacksCount), and the others
    // of the last 24 hours
    public function unfinishedActions(User $user)
    {
        return ClanAction::query()
            ->with('game', 'defenderClan', 'attack.attackerClan', 'missionStep.mission')
            ->where('user_id', $user->id)
            ->whereNotNull('run_id')
            ->whereNull('completed_at')
            ->where(fn ($query) => $query
                ->where('created_at', '>=', now()->subDay())
                ->orWhere(fn ($q) => $q->where('type', ClanActionType::ATTACK)->whereNull('clan_attack_id')))
            ->latest('id')
            ->get();
    }

    // the end of the period: the clan runs asked or begun during it no longer count (an attack ended after the period is
    // already too late), and the attacks never ended no longer block their players
    public function cancelUnfinished(Period $period): void
    {
        ClanAction::query()
            ->whereNull('completed_at')
            ->where('created_at', '<=', $period->end_at)
            ->update(['result' => 'cancelled', 'completed_at' => now()]);
    }

    // "Annuler la partie": the clan run no longer counts (if the run ends anyway, it is a normal run)
    public function cancel(User $user, ClanAction $action): void
    {
        if ($action->user_id !== $user->id || $action->run_id === null || $action->completed_at !== null) {
            throw new ClanException('Cette partie de clan n\'est pas en cours.');
        }

        $action->update(['result' => 'cancelled', 'completed_at' => now()]);
    }

    // the clan run of the page where the game is played (/clans/play/{action}, sent by the game when the run begins): it
    // goes on there while its target is open, however long the player stays on the page (pendingAction forgets an action
    // asked ACTION_TTL_MINUTES ago: the run was a normal one, an attack or a defense lost). The action of the page, or the
    // one asked since for the same target ("Rejouer"), else a new one for a mission step. Checked again when the run
    // begins (an attack ended, a seat of attack taken...): refused with the reason rather than played for nothing. An
    // action of another game or player, none (a page of the game, a bundle built before): the clan run asked last on the
    // game
    public function pageAction(User $user, int $gameId, ?int $actionId): ?ClanAction
    {
        $page = $actionId ? ClanAction::query()->find($actionId) : null;
        if (!$page || (int) $page->user_id !== $user->id || (int) $page->game_id !== $gameId) {
            return $this->pendingAction($user->id, $gameId);
        }

        // (one at most not begun: ClanService::forgetUnplayedActions)
        $action = ClanAction::query()
            ->where('user_id', $user->id)
            ->where('game_id', $gameId)
            ->where('type', $page->type)
            ->where('id', '>=', $page->id)
            ->whereNull('run_id')
            ->whereNull('completed_at')
            ->where(match ($page->type) {
                ClanActionType::MISSION => ['clan_mission_step_id' => $page->clan_mission_step_id],
                // a new attack, then its improvements
                ClanActionType::ATTACK => ['defender_clan_id' => $page->defender_clan_id],
                ClanActionType::DEFENSE => ['clan_attack_id' => $page->clan_attack_id],
            })
            ->latest('id')
            ->first();

        if ($page->type === ClanActionType::MISSION) {
            $step = ClanMissionStep::query()->find($page->clan_mission_step_id);
            $closed = $this->closedStepReason($step);
            if ($closed !== null) {
                $action?->update(['result' => 'too_late', 'completed_at' => now()]);

                throw new ClanException($closed.' Retournez sur la page des missions de votre clan.');
            }

            // (refused out of the clan)
            return $action ?? $this->missionService->startStep($user, $step);
        }

        // an attack or a defense played on the page, and "Rejouer" not asked (the page said the next run would be a
        // normal one): the clan run asked last
        if (!$action) {
            return $this->pendingAction($user->id, $gameId);
        }
        $closed = $this->closedWarReason($action, $user);
        if ($closed !== null) {
            $action->update(['result' => 'too_late', 'completed_at' => now()]);

            throw new ClanException($closed.' Retournez sur la page de votre clan.');
        }

        return $action;
    }

    // the page of a clan run shows the game: a mission step while it is open, an attack or a defense not begun while its
    // target is open (pageAction)
    public function isOpen(ClanAction $action): bool
    {
        if ($action->type === ClanActionType::MISSION) {
            return $this->closedStepReason(ClanMissionStep::query()->find($action->clan_mission_step_id)) === null;
        }

        $user = User::query()->find($action->user_id);

        return $user && $action->run_id === null && $action->completed_at === null && $this->closedWarReason($action, $user) === null;
    }

    // why an attack or a defense can't be played (null while it can): checked again when its run begins, as
    // ClanWarService::startAttack / startImprovement / startDefense when it was asked
    private function closedWarReason(ClanAction $action, User $user): ?string
    {
        $clanId = (int) $user->clanMember()->value('clan_id');
        if ($action->clan_attack_id === null) {
            $clan = Clan::query()->find($action->clan_id);
            if (!$clan || $clanId !== $clan->id) {
                return 'Vous ne faites plus partie de ce clan.';
            }

            // (an "Attaquant" whose seat was taken back, attacks launched from another page)
            return $this->warService->runningAttacksCount($user) >= $this->warService->maxAttacks($user, $clan)
                ? 'Vous avez déjà le maximum d\'attaques en cours.'
                : null;
        }

        $attack = ClanAttack::query()->find($action->clan_attack_id);
        if (!$attack || $attack->status !== ClanAttackStatus::ACTIVE || $attack->expires_at->isPast()) {
            return 'Cette attaque est terminée.';
        }
        // the attacker for an improvement, a member of the clan attacked for a defense
        $side = $action->type === ClanActionType::ATTACK ? $attack->attacker_clan_id : $attack->defender_clan_id;
        if ($clanId !== (int) $side) {
            return 'Vous ne faites plus partie de ce clan.';
        }

        return null;
    }

    // why a mission step can't be played (null while it is open)
    private function closedStepReason(?ClanMissionStep $step): ?string
    {
        $mission = $step ? ClanMission::query()->find($step->clan_mission_id) : null;

        return match (true) {
            !$mission || $mission->status !== ClanMission::ACTIVE || $mission->expires_at->isPast() => 'Cette mission est terminée.',
            $step->isDone() => 'Cette étape a déjà été réussie.',
            default => null,
        };
    }

    // the clan run asked by the player on this game, not begun yet
    public function pendingAction(int $userId, int $gameId): ?ClanAction
    {
        $action = ClanAction::query()
            ->where('user_id', $userId)
            ->where('game_id', $gameId)
            ->whereNull('run_id')
            ->whereNull('completed_at')
            ->where('created_at', '>=', now()->subMinutes(ClanWarService::ACTION_TTL_MINUTES))
            ->latest('id')
            ->first()
            ?? $this->continueFailedStep($userId, $gameId);

        // a mission step completed by another member (or a mission over) since it was asked: the run is refused (the game
        // shows why) rather than played for nothing, or as a normal run costing a game
        if ($action?->type === ClanActionType::MISSION) {
            $closed = $this->closedStepReason($action->missionStep);
            if ($closed !== null) {
                $action->update(['result' => 'too_late', 'completed_at' => now()]);

                throw new ClanException($closed.' Retournez sur la page des missions de votre clan.');
            }
        }

        // a new attack checked again when it begins (out of the clan, or the maximum of attacks reached meanwhile: his seat
        // of "Attaquant" taken back...): forgotten, the run is a normal one
        if ($action?->type === ClanActionType::ATTACK && $action->clan_attack_id === null) {
            $user = $action->user;
            $clan = $action->clan;
            if (!$clan || (int) $user->clanMember()->value('clan_id') !== $clan->id
                || $this->warService->runningAttacksCount($user) >= $this->warService->maxAttacks($user, $clan)) {
                $action->delete();

                return null;
            }
        }

        return $action;
    }

    // "Rejouer" after a failed mission step, begun before the page asked for it (ClanActionController::again, sent once
    // the end of the run is received: a quick click on the end screen of the game is sooner): the run goes on with the
    // step while it is open. Only right after it (the last clan run of the player, on this game, ACTION_TTL_MINUTES ago at
    // most)
    private function continueFailedStep(int $userId, int $gameId): ?ClanAction
    {
        $last = ClanAction::query()->where('user_id', $userId)->latest('id')->first();
        if ($last?->type !== ClanActionType::MISSION || (int) $last->game_id !== $gameId || $last->result !== 'failed'
            || $last->completed_at === null || $last->completed_at->lt(now()->subMinutes(ClanWarService::ACTION_TTL_MINUTES))) {
            return null;
        }

        try {
            return $this->missionService->startStep($last->user, $last->missionStep);
        } catch (ClanException) {
            // (the step completed meanwhile, the mission over...: a normal run)
            return null;
        }
    }

    // a mission step
    public const COST_FREE = 'free';

    // a normal run: a game of the day
    public const COST_GAME = 'game';

    // an attack or a defense: an attack game of the day, else a paid clan game
    public const COST_CLAN = 'clan';

    public function runCost(?ClanAction $action): string
    {
        return match ($action?->type) {
            ClanActionType::MISSION => self::COST_FREE,
            ClanActionType::ATTACK, ClanActionType::DEFENSE => self::COST_CLAN,
            null => self::COST_GAME,
        };
    }

    public function hasClanGame(User $user): bool
    {
        return $user->clan_attack_games > 0 || $user->clan_games > 0;
    }

    // an attack game of the day, else a paid clan game; false when there is none left
    public function useClanGame(User $user): bool
    {
        $used = User::query()->whereKey($user->id)->where('clan_attack_games', '>', 0)->decrement('clan_attack_games') > 0
            || User::query()->whereKey($user->id)->where('clan_games', '>', 0)->decrement('clan_games') > 0;
        if ($used) {
            Realtime::send(new UserCountersChanged($user->id));
        }

        return $used;
    }

    // shown in the bottom bar of the game instead of the contract: the score to reach (a mission step, a defense: higher than
    // the attack), the score of the attack to improve (0 for a new attack), and the clan games left
    /**
     * @return array{type: string, score: int, attack_games: int, clan_games: int}
     */
    public function goal(ClanAction $action, User $user): array
    {
        return [
            'type' => $action->type->value,
            'score' => match ($action->type) {
                ClanActionType::MISSION => $action->missionStep->target_score,
                ClanActionType::DEFENSE => $action->attack->score + 1,
                ClanActionType::ATTACK => $action->attack?->score ?? 0,
            },
            'attack_games' => $user->clan_attack_games,
            'clan_games' => $user->clan_games,
        ];
    }

    public function bindRun(Run $run, ?ClanAction $action = null): ?ClanAction
    {
        if ($run->daily_game_id) {
            return null;
        }

        $action ??= $this->pendingAction($run->user_id, $run->game_id);
        $action?->update(['run_id' => $run->id]);

        return $action;
    }

    /**
     * @return array{type: string, result: string, message: string}|null
     */
    public function handleRunCompleted(Run $run): ?array
    {
        $action = ClanAction::query()->where('run_id', $run->id)->whereNull('completed_at')->first();
        if (!$action) {
            return null;
        }

        $result = $run->is_cheat ? 'cheat' : match ($action->type) {
            ClanActionType::ATTACK => $this->warService->completeAttack($action, $run),
            ClanActionType::DEFENSE => $this->warService->completeDefense($action, $run),
            ClanActionType::MISSION => $this->missionService->completeStep($action, $run),
        };
        $action->update(['result' => $result, 'completed_at' => now()]);

        return [
            'type' => $action->type->value,
            'result' => $result,
            'message' => $this->message($action->type, $result),
        ];
    }

    // a run found cheated after it counted for the clan (RunService::flagAsCheat)
    public function revertCheatedRun(Run $run): void
    {
        $this->warService->revertCheatedRun($run);
        $this->missionService->revertCheatedRun($run);
    }

    // the run of an attack, a defense or a mission step: its replay is verified like a run that counts
    // (ReplayVerifier::shouldVerify)
    public function isClanRun(Run $run): bool
    {
        return ClanAction::query()->where('run_id', $run->id)->exists();
    }

    private function message(ClanActionType $type, string $result): string
    {
        return match ([$type, $result]) {
            [ClanActionType::ATTACK, 'launched'] => 'Votre attaque est lancée ! Le clan adverse a '.app(ClanSettings::class)->attack_hours.' heures pour la repousser.',
            [ClanActionType::ATTACK, 'improved'] => 'Votre attaque est améliorée : le clan adverse devra battre ce nouveau score.',
            [ClanActionType::ATTACK, 'not_improved'] => 'Ce score n\'est pas meilleur que celui de votre attaque : elle garde son score.',
            [ClanActionType::DEFENSE, 'repelled'] => 'Bravo, vous avez repoussé l\'attaque !',
            [ClanActionType::DEFENSE, 'failed'] => 'Votre score n\'est pas suffisant pour repousser l\'attaque.',
            [ClanActionType::MISSION, 'completed'] => 'Étape de mission réussie !',
            [ClanActionType::MISSION, 'failed'] => 'Le score à atteindre pour cette étape n\'est pas atteint.',
            default => $result === 'cheat' ? 'Cette partie ne compte pas pour votre clan.' : 'Trop tard : cette action de clan est terminée.',
        };
    }
}
