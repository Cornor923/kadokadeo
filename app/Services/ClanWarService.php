<?php

namespace App\Services;

use App\Enums\ClanActionType;
use App\Enums\ClanAttackStatus;
use App\Enums\ClanCombatRole;
use App\Events\ClanToast;
use App\Events\ClanUpdated;
use App\Exceptions\ClanException;
use App\Models\Clan;
use App\Models\ClanAction;
use App\Models\ClanAttack;
use App\Models\ClanPeriodScore;
use App\Models\ClanWar;
use App\Models\Game;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use App\Settings\ClanSettings;
use App\Support\Realtime;
use Illuminate\Support\Facades\DB;

// the attacks and defenses of the clans: the score of an attack must be beaten by the attacked clan within
// ClanSettings::$attack_hours, otherwise the attacker wins points and the defender loses as many. A repelled attack costs
// nothing to the attacker. One attack at a time by player (two for an "Attaquant"), as many received as can be. Both
// clans see the changes at once (App\Events\ClanUpdated), the defenders a toast for a defense won (App\Events\ClanToast).
class ClanWarService
{
    // a clan run asked but not begun after this time is forgotten by the runs begun elsewhere than on its page
    // (ClanRunService::pendingAction, pageAction)
    public const ACTION_TTL_MINUTES = 15;

    // the wars a clan can declare at the same time
    public const MAX_WARS = 3;

    public function __construct(private readonly ClanService $clanService) {}

    // ---------------------------------------------------------------- wars

    // "Déclarer la guerre": the clan of the leader or the right hand shows the target to its members (the "Statut" of both
    // clans) until the end of the period (endWarsOf). Nothing else changes: any clan can still be attacked.
    public function declareWar(User $user, Clan $target): ClanWar
    {
        $clan = $this->clanService->clanOf($user);
        if (!$clan) {
            throw new ClanException('Vous n\'avez pas de clan.');
        }
        $this->clanService->assertManager($user, $clan);
        if ($clan->id === $target->id) {
            throw new ClanException('Vous ne pouvez pas déclarer la guerre à votre propre clan.');
        }

        return DB::transaction(function () use ($user, $clan, $target) {
            // (two managers at the same time: the 3 wars at most stay true)
            Clan::query()->lockForUpdate()->find($clan->id);
            $existing = ClanWar::query()->where('clan_id', $clan->id)->where('target_clan_id', $target->id)->first();
            if ($existing) {
                return $existing;
            }
            if (ClanWar::query()->where('clan_id', $clan->id)->count() >= self::MAX_WARS) {
                throw new ClanException('Votre clan est déjà en guerre contre '.self::MAX_WARS.' clans : faites la paix avec l\'un d\'eux d\'abord.');
            }

            $war = ClanWar::query()->create([
                'clan_id' => $clan->id,
                'target_clan_id' => $target->id,
                'declared_by_user_id' => $user->id,
            ]);
            ClanUpdated::send([$clan->id, $target->id], [ClanUpdated::STATUS]);

            return $war;
        });
    }

    // "Faire la paix": the war declared by the clan of the player ends
    public function endWar(User $user, Clan $target): void
    {
        $clan = $this->clanService->clanOf($user);
        if (!$clan) {
            throw new ClanException('Vous n\'avez pas de clan.');
        }
        $this->clanService->assertManager($user, $clan);

        if (ClanWar::query()->where('clan_id', $clan->id)->where('target_clan_id', $target->id)->delete() > 0) {
            ClanUpdated::send([$clan->id, $target->id], [ClanUpdated::STATUS]);
        }
    }

    // the wars declared by the clan and against it, the newest first
    public function warsOf(Clan $clan)
    {
        return ClanWar::query()
            ->with('clan:id,name', 'targetClan:id,name')
            ->where(fn ($query) => $query->where('clan_id', $clan->id)->orWhere('target_clan_id', $clan->id))
            ->latest('id')
            ->get();
    }

    // an attack game of the day or a paid clan game (used when the run begins, ClanRunService::useClanGame)
    private function assertClanGame(User $user): void
    {
        $user = $user->fresh();
        if ($user->clan_attack_games <= 0 && $user->clan_games <= 0) {
            throw new ClanException('Vous n\'avez plus de parties d\'attaque aujourd\'hui. Vous pouvez acheter des parties de clan avec vos points Kado.');
        }
    }

    public function startAttack(User $user, Clan $defender, Game $game): ClanAction
    {
        $period = $this->clanService->assertPeriod();
        $clan = $this->clanService->clanOf($user);
        if (!$clan) {
            throw new ClanException('Vous devez faire partie d\'un clan pour attaquer.');
        }
        if ($clan->id === $defender->id) {
            throw new ClanException('Vous ne pouvez pas attaquer votre propre clan.');
        }
        if (!$game->is_active) {
            throw new ClanException('Ce jeu n\'est pas disponible.');
        }
        $attackerScore = $this->clanService->warScore($clan, $period);
        $defenderScore = $this->clanService->warScore($defender, $period);
        if ($this->clanService->isProtected($attackerScore, $defenderScore)) {
            throw new ClanException('Ce clan est protégé de vos attaques : son score est trop éloigné du vôtre.');
        }

        return DB::transaction(function () use ($user, $clan, $defender, $game) {
            // the player locked: two attacks asked at the same time are counted one after the other (the attack asked
            // before and not begun is forgotten, the one begun counts)
            User::query()->lockForUpdate()->find($user->id);
            $this->clanService->forgetUnplayedActions($user);
            $this->assertClanGame($user);
            if ($this->runningAttacksCount($user) >= $this->maxAttacks($user, $clan)) {
                throw new ClanException('Vous avez déjà le maximum d\'attaques en cours. Vous pouvez améliorer ou annuler une attaque depuis la page statut de votre clan.');
            }

            return ClanAction::query()->create([
                'clan_id' => $clan->id,
                'user_id' => $user->id,
                'game_id' => $game->id,
                'type' => ClanActionType::ATTACK,
                'defender_clan_id' => $defender->id,
            ]);
        });
    }

    // the attacker, still in the clan of the attack (a member who left or was excluded no longer acts for it)
    private function isAttacker(User $user, ClanAttack $attack): bool
    {
        return $attack->attacker_user_id === $user->id && $this->clanService->clanOf($user)?->id === $attack->attacker_clan_id;
    }

    // a new run on the game of his attack: its score replaces the score of the attack only if it is higher
    public function startImprovement(User $user, ClanAttack $attack): ClanAction
    {
        $this->resolveExpired();
        $attack->refresh();
        if (!$this->isAttacker($user, $attack)) {
            throw new ClanException('Seul l\'attaquant peut améliorer son attaque.');
        }
        if ($attack->status !== ClanAttackStatus::ACTIVE) {
            throw new ClanException('Cette attaque est terminée.');
        }
        $this->clanService->forgetUnplayedActions($user);
        $this->assertClanGame($user);

        return ClanAction::query()->create([
            'clan_id' => $attack->attacker_clan_id,
            'user_id' => $user->id,
            'game_id' => $attack->game_id,
            'type' => ClanActionType::ATTACK,
            'defender_clan_id' => $attack->defender_clan_id,
            'clan_attack_id' => $attack->id,
        ]);
    }

    public function startDefense(User $user, ClanAttack $attack): ClanAction
    {
        $this->resolveExpired();
        $attack->refresh();

        $clan = $this->clanService->clanOf($user);
        if (!$clan || $clan->id !== $attack->defender_clan_id) {
            throw new ClanException('Seuls les membres du clan attaqué peuvent défendre.');
        }
        if ($attack->status !== ClanAttackStatus::ACTIVE) {
            throw new ClanException('Cette attaque est terminée.');
        }
        $this->clanService->forgetUnplayedActions($user);
        $this->assertClanGame($user);
        // a "Défenseur" defends while he attacks
        if ($this->runningAttacksCount($user) > 0 && $this->clanService->combatRoleOf($user, $clan) !== ClanCombatRole::DEFENDER) {
            throw new ClanException('Vous ne pouvez pas défendre tant que vous avez une attaque en cours.');
        }

        return ClanAction::query()->create([
            'clan_id' => $clan->id,
            'user_id' => $user->id,
            'game_id' => $attack->game_id,
            'type' => ClanActionType::DEFENSE,
            'clan_attack_id' => $attack->id,
        ]);
    }

    // "Je m'en occupe": a member of the attacked clan says he will beat the score later. Any member can take the place,
    // the one who reserved can give it up (only an information for the clan).
    public function reserveDefense(User $user, ClanAttack $attack): void
    {
        $clan = $this->clanService->clanOf($user);
        if (!$clan || $clan->id !== $attack->defender_clan_id) {
            throw new ClanException('Seuls les membres du clan attaqué peuvent réserver la défense.');
        }
        if ($attack->status !== ClanAttackStatus::ACTIVE || $attack->expires_at->isPast()) {
            throw new ClanException('Cette attaque est terminée.');
        }

        $attack->update($attack->reserved_by_user_id === $user->id
            ? ['reserved_by_user_id' => null, 'reserved_at' => null]
            : ['reserved_by_user_id' => $user->id, 'reserved_at' => now()]);
        ClanUpdated::send([$attack->defender_clan_id], [ClanUpdated::STATUS]);
    }

    public function cancelAttack(User $user, ClanAttack $attack): void
    {
        if (!$this->isAttacker($user, $attack)) {
            throw new ClanException('Seul l\'attaquant peut annuler son attaque.');
        }

        DB::transaction(function () use ($attack) {
            $attack = ClanAttack::query()->lockForUpdate()->findOrFail($attack->id);
            if ($attack->status !== ClanAttackStatus::ACTIVE) {
                throw new ClanException('Cette attaque est terminée.');
            }

            $attack->update(['status' => ClanAttackStatus::CANCELLED, 'resolved_at' => now()]);
            $this->attackChanged($attack);
        });
    }

    // the score of the attack run becomes the attack
    public function completeAttack(ClanAction $action, Run $run): string
    {
        if ($action->clan_attack_id) {
            return $this->completeImprovement($action, $run);
        }

        $period = $run->period ?? $this->clanService->currentPeriod();
        // the period ended during the run: the tournament started again
        if (!$period || $period->end_at->isPast()) {
            return 'too_late';
        }

        DB::transaction(function () use ($action, $run, $period) {
            $attack = ClanAttack::query()->create([
                'period_id' => $period->id,
                'game_id' => $run->game_id,
                'attacker_clan_id' => $action->clan_id,
                'attacker_user_id' => $action->user_id,
                'defender_clan_id' => $action->defender_clan_id,
                'run_id' => $run->id,
                'score' => $run->score,
                'status' => ClanAttackStatus::ACTIVE,
                'expires_at' => now()->addHours(app(ClanSettings::class)->attack_hours),
            ]);
            $this->clanService->memberStat($action->clan_id, $action->user_id, $period->id)->increment('attacks');
            $this->attackChanged($attack);
        });

        return 'launched';
    }

    // a higher score replaces the score of the attack, and the defenders have the whole time again to beat it
    private function completeImprovement(ClanAction $action, Run $run): string
    {
        return DB::transaction(function () use ($action, $run) {
            $attack = ClanAttack::query()->lockForUpdate()->findOrFail($action->clan_attack_id);
            if ($attack->status !== ClanAttackStatus::ACTIVE || $attack->expires_at->isPast()) {
                return 'too_late';
            }
            if ($run->score <= $attack->score) {
                return 'not_improved';
            }

            $attack->update([
                'score' => $run->score,
                'run_id' => $run->id,
                'expires_at' => now()->addHours(app(ClanSettings::class)->attack_hours),
            ]);
            $this->attackChanged($attack);

            return 'improved';
        });
    }

    // the attack is repelled when its score is beaten before its end
    public function completeDefense(ClanAction $action, Run $run): string
    {
        return DB::transaction(function () use ($action, $run) {
            $attack = ClanAttack::query()->lockForUpdate()->findOrFail($action->clan_attack_id);
            $score = $run->score;

            $this->clanService->memberStat($action->clan_id, $action->user_id, $attack->period_id)->increment('defenses');

            if ($attack->status !== ClanAttackStatus::ACTIVE || $attack->expires_at->isPast()) {
                return 'too_late';
            }
            if ($score <= $attack->score) {
                return 'failed';
            }

            $period = $attack->period;
            $saved = $this->clanService->attackPoints(
                $this->clanService->periodScore($attack->attackerClan, $period)->war_score,
                $this->clanService->periodScore($attack->defenderClan, $period)->war_score,
            );
            $attack->update([
                'status' => ClanAttackStatus::REPELLED,
                'defender_user_id' => $action->user_id,
                'defense_run_id' => $run->id,
                // the points of the defender in the ranking of his clan (the scores of the clans do not change)
                'points' => $saved,
                'resolved_at' => now(),
            ]);
            $this->clanService->periodScore($attack->defenderClan, $period)->increment('defenses_won');
            $stat = $this->clanService->memberStat($action->clan_id, $action->user_id, $period->id);
            $stat->increment('defenses_won');
            $stat->increment('performance', $saved);
            $this->attackChanged($attack);
            $defender = User::query()->find($action->user_id);
            if ($defender && $attack->game) {
                Realtime::send(ClanToast::defenseRepelled($action->clan_id, $defender, $attack->game, (int) $score));
            }

            return 'repelled';
        });
    }

    // a run found cheated after it counted (RunService::flagAsCheat): its attack still waiting for a defense is
    // cancelled, its defense undone (the attack waits again for a defense, or is won by the attacker once its time is
    // over: resolveExpired). An attack already won stays (an admin decides)
    public function revertCheatedRun(Run $run): void
    {
        DB::transaction(function () use ($run) {
            $cancelled = ClanAttack::query()->where('run_id', $run->id)->where('status', ClanAttackStatus::ACTIVE)->get();
            ClanAttack::query()
                ->whereKey($cancelled->modelKeys())
                ->update(['status' => ClanAttackStatus::CANCELLED, 'resolved_at' => now()]);
            $cancelled->each(fn (ClanAttack $attack) => $this->attackChanged($attack));

            $defended = ClanAttack::query()
                ->where('defense_run_id', $run->id)
                ->where('status', ClanAttackStatus::REPELLED)
                ->lockForUpdate()
                ->get();
            foreach ($defended as $attack) {
                $this->undoDefenseStats($this->clanService->periodScore($attack->defenderClan, $attack->period), 'defenses_won', 1);
                $stat = $this->clanService->memberStat($attack->defender_clan_id, $attack->defender_user_id, $attack->period_id);
                $this->undoDefenseStats($stat, 'defenses_won', 1);
                $this->undoDefenseStats($stat, 'performance', (int) $attack->points);
                $attack->update([
                    'status' => ClanAttackStatus::ACTIVE,
                    'defender_user_id' => null,
                    'defense_run_id' => null,
                    'points' => 0,
                    'resolved_at' => null,
                ]);
                $this->attackChanged($attack);
            }
        });
    }

    // (never below 0)
    private function undoDefenseStats($row, string $column, int $amount): void
    {
        if ($amount > 0) {
            $row->newQuery()->whereKey($row->getKey())->where($column, '>=', $amount)->decrement($column, $amount);
        }
    }

    // the attacks of a closed period still waiting for a defense count for nothing: the scores start again from 0
    public function cancelUnfinished(Period $period): void
    {
        ClanAttack::query()
            ->active()
            ->where('period_id', $period->id)
            ->update(['status' => ClanAttackStatus::CANCELLED, 'resolved_at' => now()]);
    }

    // the wars end with the period (declared before its end only: closePeriod can run again once the next period started)
    public function endWarsOf(Period $period): void
    {
        ClanWar::query()->where('created_at', '<=', $period->end_at)->delete();
    }

    // the attacks not repelled in time are won
    public function resolveExpired(): int
    {
        $count = 0;
        $attackIds = ClanAttack::query()->active()->where('expires_at', '<=', now())->pluck('id');
        foreach ($attackIds as $attackId) {
            DB::transaction(function () use ($attackId, &$count) {
                $attack = ClanAttack::query()->lockForUpdate()->find($attackId);
                if (!$attack || $attack->status !== ClanAttackStatus::ACTIVE) {
                    return;
                }

                $period = $attack->period;
                // both scores locked (in the order of their ids: two attacks between the same clans resolved together),
                // then read again: the points and the score of the defender computed from the true scores
                $scoreIds = [
                    $this->clanService->periodScore($attack->attackerClan, $period)->id,
                    $this->clanService->periodScore($attack->defenderClan, $period)->id,
                ];
                $scores = ClanPeriodScore::query()->whereKey($scoreIds)->orderBy('id')->lockForUpdate()->get()->keyBy('clan_id');
                $attackerScore = $scores->get($attack->attacker_clan_id);
                $defenderScore = $scores->get($attack->defender_clan_id);
                $points = $this->clanService->attackPoints($attackerScore->war_score, $defenderScore->war_score);

                $attack->update(['status' => ClanAttackStatus::WON, 'points' => $points, 'resolved_at' => now()]);
                $attackerScore->increment('war_score', $points);
                $attackerScore->increment('attacks_won');
                $defenderScore->update(['war_score' => max(0, $defenderScore->war_score - $points)]);
                $defenderScore->increment('attacks_lost');
                $stat = $this->clanService->memberStat($attack->attacker_clan_id, $attack->attacker_user_id, $period->id);
                $stat->increment('attacks_won');
                $stat->increment('performance', $points);
                $this->attackChanged($attack);
                $count++;
            });
        }

        return $count;
    }

    // the attacker and the defender see it (their status, their history)
    private function attackChanged(ClanAttack $attack): void
    {
        ClanUpdated::send([$attack->attacker_clan_id, $attack->defender_clan_id], [ClanUpdated::STATUS, ClanUpdated::HISTORY]);
    }

    // his attacks waiting for a defense, and the new attack runs he is playing: whatever their length, until they end or he
    // cancels them (« Annuler la partie », ClanRunService::cancel); the end of the period cancels them too
    public function runningAttacksCount(User $user): int
    {
        return ClanAttack::query()->active()->where('attacker_user_id', $user->id)->count()
            + ClanAction::query()
                ->where('user_id', $user->id)
                ->where('type', ClanActionType::ATTACK)
                ->whereNull('clan_attack_id')
                ->whereNotNull('run_id')
                ->whereNull('completed_at')
                ->count();
    }

    // two for an "Attaquant", one for the others
    public function maxAttacks(User $user, Clan $clan): int
    {
        return $this->clanService->combatRoleOf($user, $clan) === ClanCombatRole::ATTACKER ? 2 : 1;
    }
}
