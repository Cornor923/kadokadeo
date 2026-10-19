<?php

namespace App\Http\Controllers\Api;

use App\Enums\ClanActionType;
use App\Http\Controllers\Controller;
use App\Models\Clan;
use App\Models\ClanAction;
use App\Models\ClanAttack;
use App\Models\ClanMission;
use App\Models\ClanMissionStep;
use App\Models\Game;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use App\Services\ClanMissionService;
use App\Services\ClanPeriodService;
use App\Services\ClanService;
use App\Services\ClanWarService;
use App\Services\GameService;
use App\Services\LeagueService;
use App\Services\PoidsPlumeService;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\DB;

// tools to try the clans alone (kado.debug_tools, never in production): runs with a chosen score as an attack, a defense
// or a mission step, the time going by for the attacks and the missions, the end of the period
class DebugClanController extends Controller implements HasMiddleware
{
    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum'),
            function ($request, $next) {
                abort_unless(config('kado.debug_tools'), 404);

                return $next($request);
            },
        ];
    }

    public function __construct(
        private readonly ClanService $clanService,
        private readonly ClanWarService $warService,
        private readonly ClanMissionService $missionService,
        private readonly GameService $gameService,
    ) {}

    // what the page needs: the clans, the attacks in progress, the mission of the clan of the player
    public function index(Request $request)
    {
        $period = $this->clanService->currentPeriod();
        $this->warService->resolveExpired();
        $myClan = $this->clanService->clanOf($request->user());
        $mission = $myClan && $period ? $this->missionService->currentMission($myClan, $period)?->load('steps.game') : null;

        return [
            'data' => [
                'period' => $period?->only(['id', 'start_at', 'end_at']),
                'my_clan_id' => $myClan?->id,
                'clans' => Clan::query()->with('leader:id,display_name')->withCount('members')->orderBy('name')->get()
                    ->map(fn (Clan $clan) => [
                        'id' => $clan->id,
                        'name' => $clan->name,
                        'leader' => $clan->leader?->display_name,
                        'members_count' => $clan->members_count,
                        'war_score' => $period ? $this->clanService->warScore($clan, $period) : 0,
                    ]),
                'games' => Game::query()->where('is_active', true)->where('is_arkadeo', false)->orderBy('name')->get(['id', 'name']),
                'attacks' => ClanAttack::query()->active()->with('game', 'attackerClan', 'defenderClan', 'attackerUser')->latest('id')->get()
                    ->map(fn (ClanAttack $attack) => [
                        'id' => $attack->id,
                        'attacker' => $attack->attackerUser->display_name,
                        'attacker_clan' => $attack->attackerClan->name,
                        'defender_clan' => $attack->defenderClan->name,
                        'game' => $attack->game->name,
                        'score' => $attack->score,
                        'expires_at' => $attack->expires_at?->toIso8601String(),
                    ]),
                'mission' => $mission ? [
                    'number' => $mission->number,
                    'expires_at' => $mission->expires_at->toIso8601String(),
                    'reward' => $this->missionService->missionPoints($mission->number),
                    'steps' => $mission->steps->map(fn (ClanMissionStep $step) => [
                        'id' => $step->id,
                        'game' => $step->game->name,
                        'target_score' => $step->target_score,
                        'done' => $step->isDone(),
                    ]),
                ] : null,
            ],
        ];
    }

    // a run of a member of the attacker clan (the player if he is one of them, else its leader) with this score
    public function attack(Request $request)
    {
        $validated = $request->validate([
            'attacker_clan_id' => ['required', 'integer', 'exists:clans,id'],
            'defender_clan_id' => ['required', 'integer', 'exists:clans,id', 'different:attacker_clan_id'],
            'game_id' => ['required', 'integer', 'exists:games,id'],
            'score' => ['required', 'integer', 'min:0'],
        ]);
        $attackerClan = Clan::query()->findOrFail($validated['attacker_clan_id']);
        $user = $this->memberOf($request->user(), $attackerClan);
        $action = $this->action($user, $attackerClan, $validated['game_id'], ClanActionType::ATTACK, ['defender_clan_id' => $validated['defender_clan_id']]);

        return ['data' => ['result' => $this->play($action, $validated['score'])]];
    }

    // a run of a member of the attacked clan with this score
    public function defend(Request $request, ClanAttack $attack)
    {
        $validated = $request->validate(['score' => ['required', 'integer', 'min:0']]);
        $user = $this->memberOf($request->user(), $attack->defenderClan);
        $action = $this->action($user, $attack->defenderClan, $attack->game_id, ClanActionType::DEFENSE, ['clan_attack_id' => $attack->id]);

        return ['data' => ['result' => $this->play($action, $validated['score'])]];
    }

    // a run of the player reaching the score of a step of the mission of his clan
    public function missionStep(Request $request, ClanMissionStep $step)
    {
        $clan = $step->mission->clan;
        $user = $this->memberOf($request->user(), $clan);
        $action = $this->action($user, $clan, $step->game_id, ClanActionType::MISSION, ['clan_mission_step_id' => $step->id]);

        return ['data' => ['result' => $this->play($action, $step->target_score)]];
    }

    // the attacks and the missions in progress as if these hours had gone by
    public function time(Request $request)
    {
        $validated = $request->validate(['hours' => ['required', 'integer', 'min:1', 'max:48']]);
        $hours = $validated['hours'];

        foreach (ClanAttack::query()->active()->get() as $attack) {
            $attack->update(['expires_at' => $attack->expires_at->subHours($hours)]);
        }
        foreach (ClanMission::query()->where('status', ClanMission::ACTIVE)->get() as $mission) {
            $mission->update(['expires_at' => $mission->expires_at->subHours($hours)]);
        }
        $won = $this->warService->resolveExpired();

        return ['data' => ['result' => "{$hours}h écoulées : {$won} attaque(s) réussie(s)."]];
    }

    // the end of the current period (as kado:prepare-new-period): rankings, rewards, and a new period from now
    public function endPeriod(LeagueService $leagueService, PoidsPlumeService $poidsPlumeService, ClanPeriodService $clanPeriodService)
    {
        $period = $this->clanService->currentPeriod();
        abort_unless($period, 422, 'Aucune période en cours.');

        $period->update(['end_at' => now()->subSecond()]);
        $next = Period::query()->create([
            'start_at' => now(),
            'end_at' => now()->addDays(Period::DAYS_PER_PERIOD)->endOfDay(),
        ]);
        $leagueService->closePeriod($period, $next);
        $poidsPlumeService->closePeriod($period);
        $clanPeriodService->closePeriod($period);

        return ['data' => ['result' => "Période {$period->id} terminée, période {$next->id} commencée."]];
    }

    private function memberOf(User $user, Clan $clan): User
    {
        return $this->clanService->isMember($user, $clan) ? $user : ($clan->leader ?? abort(422, 'Ce clan n\'a pas de chef.'));
    }

    private function action(User $user, Clan $clan, int $gameId, ClanActionType $type, array $target): ClanAction
    {
        return ClanAction::query()->create([
            'clan_id' => $clan->id,
            'user_id' => $user->id,
            'game_id' => $gameId,
            'type' => $type,
            ...$target,
        ]);
    }

    // a finished run with this score bound to the action, then what the clan does with it
    private function play(ClanAction $action, int $score): string
    {
        return DB::transaction(function () use ($action, $score) {
            $period = $this->clanService->currentPeriod();
            $run = Run::query()->create([
                'game_id' => $action->game_id,
                'user_id' => $action->user_id,
                'period_id' => $period?->id,
                'seed' => $this->gameService->generateSeed(),
                'contract_score' => 0,
                'contract_points' => 0,
                'score' => $score,
                'completed_at' => now(),
            ]);
            $action->update(['run_id' => $run->id]);
            $result = app(\App\Services\ClanRunService::class)->handleRunCompleted($run);

            return ($result['message'] ?? 'Rien ne s\'est passé.').($action->type === ClanActionType::ATTACK && $result['result'] === 'launched'
                ? ' (attaque de '.$action->user->display_name.')'
                : '');
        });
    }
}
