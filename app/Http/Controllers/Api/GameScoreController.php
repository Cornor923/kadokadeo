<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\RunResource;
use App\Http\Resources\UserLightResource;
use App\Models\Game;
use App\Models\Period;
use App\Services\GameService;
use App\Services\LeagueService;
use App\Services\PoidsPlumeService;
use App\Services\ScoreService;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Gate;

class GameScoreController extends Controller implements HasMiddleware
{
    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum', only: ['index', 'show', 'daily', 'dailyScores', 'siteRecords', 'personalRecords', 'userPeriodRecords', 'competition', 'poidsPlumes']),
        ];
    }

    public function index(Game $game, ScoreService $scoreService, LeagueService $leagueService)
    {
        $currentPeriod = Period::current()->first();
        $league = $currentPeriod ? $leagueService->getCurrentLeagueFor(Auth::user(), $game, $currentPeriod) : null;
        $scores = $scoreService->getLeaderBoard($game, $currentPeriod?->id, $league?->id)->take(10)->get();
        $personalBest = $scoreService->getUserBestScore($game, Auth::id());
        $personalBestForPeriod = $scoreService->getUserBestScore($game, Auth::id(), $currentPeriod?->id);
        $worldsBest = $scoreService->getUserBestScore($game, null);
        $leaguesScores = $currentPeriod ? $scoreService->getLeagueScoresForPromotion($game, $currentPeriod?->id) : [];

        return response()->json([
            'scores' => RunResource::collection($scores),
            'worlds_best' => $worldsBest ? RunResource::make($worldsBest) : null,
            'personal_best' => $personalBest ? RunResource::make($personalBest) : null,
            'personal_best_for_period' => $personalBestForPeriod ? RunResource::make($personalBestForPeriod) : null,
            'league' => $league,
            'leagues_scores' => $leaguesScores,
        ]);
    }

    public function siteRecords(ScoreService $scoreService)
    {
        $records = Game::query()
            ->where('is_active', true)
            ->orderBy('name')
            ->get()
            ->map(function (Game $game) use ($scoreService) {
                $bestRun = $scoreService->getBestScore($game, null);
                $bestRun?->load('user');

                return [
                    'game' => [
                        'id' => $game->id,
                        'name' => $game->name,
                    ],
                    'record' => $bestRun?->score,
                    'run_id' => $bestRun?->id,
                    'has_replay' => $bestRun?->has_replay ?? false,
                    'user' => $bestRun?->user ? UserLightResource::make($bestRun->user) : null,
                ];
            });

        return response()->json($records);
    }

    public function personalRecords(ScoreService $scoreService, LeagueService $leagueService)
    {
        $userId = Auth::id();
        $currentPeriod = Period::current()->first();
        $currentPeriodId = $currentPeriod?->id;
        $records = Game::query()
            ->where('is_active', true)
            ->orderBy('name')
            ->get()
            ->map(fn (Game $game) => [
                'game' => [
                    'id' => $game->id,
                    'name' => $game->name,
                    'stars' => $game->stars,
                ],
                'score' => $scoreService->getUserBestScore($game, $userId)?->score,
                'current_score' => $currentPeriodId === null
                    ? null
                    : $scoreService->getUserBestScore($game, $userId, $currentPeriodId)?->score,
                'league' => $currentPeriod === null
                    ? null
                    : $leagueService->getCurrentLeagueFor(Auth::user(), $game, $currentPeriod),
            ]);

        return response()->json($records);
    }

    public function userPeriodRecords(Game $game, ScoreService $scoreService)
    {
        $scoresByPeriod = $scoreService->getUserBestScoresByPeriod($game, Auth::id());
        $periods = Period::query()
            ->orderBy('id')
            ->get(['id'])
            ->map(fn (Period $period) => [
                'id' => $period->id,
                'score' => $scoresByPeriod->get($period->id),
            ]);

        return response()->json([
            'game' => [
                'id' => $game->id,
                'name' => $game->name,
            ],
            'periods' => $periods,
        ]);
    }

    public function competition(Request $request, ScoreService $scoreService)
    {
        $request->validate([
            'period' => 'sometimes|required|integer|exists:periods,id',
        ]);
        $currentPeriod = Period::current()->first();
        $selectedPeriod = $request->has('period')
            ? Period::findOrFail($request->integer('period'))
            : $currentPeriod;

        return response()->json($scoreService->get1500Leaderboard($selectedPeriod?->id));
    }

    public function poidsPlumes(PoidsPlumeService $poidsPlumeService)
    {
        return response()->json($poidsPlumeService->getLeaderboardForPeriod(Period::current()->first()));
    }

    public function search(Request $request, Game $game, ScoreService $scoreService)
    {
        $data = $request->validate([
            'period' => 'sometimes|required|integer|min:1|max_digits:6|exists:periods,id',
            'league' => 'sometimes|required|integer|min:1|exists:leagues,id',
        ]);
        $scores = $scoreService->getLeaderBoard($game, data_get($data, 'period'), data_get($data, 'league'))->paginate(50);

        return RunResource::collection($scores);
    }

    public function dailyScores(Request $request, GameService $gameService, ScoreService $scoreService)
    {
        $dailyGame = $gameService->getDailyGame();
        Gate::authorize('view', $dailyGame?->game);

        $dailyGameRuns = $dailyGame?->runs()->whereNotNull('score')->orderByDesc('score')->with('user')->limit(10)->get() ?? collect();
        // hack to disable replay for this specific endpoint
        $dailyGameRuns->each(function ($run) {
            $run->replay = null;
        });

        $myPosition = $scoreService->getUserPositionOnDailyGame($dailyGame, Auth::id());

        return RunResource::collection($dailyGameRuns)
            ->additional([
                'position' => $myPosition,
            ]);
    }
}
