<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserLightResource;
use App\Models\Clan;
use App\Models\ClanBonus;
use App\Models\ClanMission;
use App\Models\ClanMissionStep;
use App\Models\Game;
use App\Services\ClanMissionPaliers;
use App\Services\ClanMissionService;
use App\Services\ClanService;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;

// "Mission": the mission in progress of the clan, the previous ones of the period and the options of the clan
class ClanMissionController extends Controller implements HasMiddleware
{
    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum'),
            new Middleware('throttle:30,1', only: ['play', 'reserve']),
        ];
    }

    public function __construct(
        private readonly ClanService $clanService,
        private readonly ClanMissionService $missionService,
    ) {}

    // the missions of a clan: anyone can see them, its members also see the reservations of the steps and the options of
    // the clan (its strategy)
    public function index(Request $request, Clan $clan)
    {
        $period = $this->clanService->currentPeriod();
        abort_unless($period, 404, 'Aucune période en cours.');
        $isMember = $this->clanService->isMember($request->user(), $clan);

        // (another clan looking does not start the next mission and its countdown: only the members do)
        $mission = $isMember
            ? $this->missionService->currentMission($clan, $period)
            : ClanMission::query()->where('clan_id', $clan->id)->where('period_id', $period->id)
                ->where('status', ClanMission::ACTIVE)->where('expires_at', '>', now())->first();
        $score = $this->clanService->periodScore($clan, $period);
        // the "Jeux caca" and the "Jeux cool", in the order they were added
        $lists = $isMember ? $this->missionService->gameLists($clan, $period) : ['banned' => collect(), 'forced' => collect()];
        $listGames = Game::query()->whereIn('id', $lists['banned']->concat($lists['forced']))->get(['id', 'name'])->keyBy('id');
        $gameList = fn ($ids) => $ids->map(fn (int $id) => $listGames->get($id)?->only(['id', 'name']))->filter()->values();
        $viewerId = $request->user()->id;

        return [
            'data' => [
                'mission' => $mission ? $this->missionData($mission->load('steps.game', 'steps.completedBy', 'steps.reservedBy'), $viewerId, $isMember) : null,
                'missions' => ClanMission::query()
                    ->where('clan_id', $clan->id)
                    ->where('period_id', $period->id)
                    ->where('status', '!=', ClanMission::ACTIVE)
                    ->with('bonus')
                    ->orderByDesc('id')
                    ->get()
                    ->map(fn (ClanMission $mission) => [
                        ...$mission->only(['id', 'number', 'status', 'points']),
                        'completed_at' => $mission->completed_at?->toIso8601String(),
                        // the option won with the mission, if any
                        'bonus' => $isMember && $mission->bonus ? $this->bonusData($mission->bonus) + ['used' => $mission->bonus->used_at !== null] : null,
                    ]),
                'mission_score' => $score->mission_score,
                'missions_completed' => $score->missions_completed,
                'banned_games' => $gameList($lists['banned']),
                'forced_games' => $gameList($lists['forced']),
                'bonuses' => $isMember
                    ? ClanBonus::query()
                        ->available()
                        ->where('clan_id', $clan->id)
                        ->where('period_id', $period->id)
                        ->orderBy('id')
                        ->get()
                        ->map(fn (ClanBonus $bonus) => $this->bonusData($bonus))
                    : [],
            ],
            'tournament' => $this->clanService->tournamentInfo(),
        ];
    }

    public function play(Request $request, ClanMissionStep $step)
    {
        $action = $this->missionService->startStep($request->user(), $step);

        return response()->json(['data' => ['id' => $action->id]], 201);
    }

    public function reserve(Request $request, ClanMissionStep $step)
    {
        $this->missionService->reserveStep($request->user(), $step);

        return response()->noContent();
    }

    public function useBonus(Request $request, ClanBonus $bonus)
    {
        $validated = $request->validate([
            'game_id' => ['sometimes', 'integer'],
            'step_id' => ['sometimes', 'integer'],
        ]);
        $this->missionService->useBonus($request->user(), $bonus, $validated);

        return response()->noContent();
    }

    private function bonusData(ClanBonus $bonus): array
    {
        return [
            'id' => $bonus->id,
            'type' => $bonus->type->value,
            'label' => $bonus->type->getLabel(),
            'description' => $bonus->type->description(),
            'icon' => $bonus->type->icon(),
        ];
    }

    private function missionData(ClanMission $mission, int $viewerId, bool $isMember): array
    {
        return [
            'id' => $mission->id,
            'number' => $mission->number,
            'status' => $mission->status,
            'expires_at' => $mission->expires_at->toIso8601String(),
            // won if all the steps are done in time, otherwise 1 point lost by step not done, minus one
            'reward' => $this->missionService->missionPoints($mission->number),
            // the hardest steps first
            'steps' => $mission->steps
                ->sortByDesc(fn (ClanMissionStep $step) => ClanMissionPaliers::difficulty($step->game->stars ?? [], $step->game->score_rankv1, $step->target_score))
                ->values()
                ->map(fn (ClanMissionStep $step) => [
                    'id' => $step->id,
                    'game' => ['id' => $step->game->id, 'name' => $step->game->name],
                    'target_score' => $step->target_score,
                    // the star of the score to reach (-1: none, 0: green, 1: orange, 2: red), above the last star
                    'star' => $step->game->getStarFromScore($step->target_score),
                    'beyond_last_star' => $step->target_score > max($step->game->stars ?: [PHP_INT_MAX]),
                    'skipped' => $step->skipped,
                    'done' => $step->isDone(),
                    'score' => $step->score,
                    'completed_by' => $step->completedBy ? UserLightResource::make($step->completedBy) : null,
                    'completed_at' => $step->completed_at?->toIso8601String(),
                    // "Je m'en occupe" (for the members)
                    'reserved_by' => $isMember && $step->reservedBy ? UserLightResource::make($step->reservedBy) : null,
                    'reserved_at' => $isMember ? $step->reserved_at?->toIso8601String() : null,
                    'reserved_by_me' => $isMember && $step->reserved_by_user_id === $viewerId,
                ]),
        ];
    }
}
