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
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Gate;

class GameScoreController extends Controller implements HasMiddleware
{
    private const COMPETITION_PER_PAGE = 50;

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
        // without the promoted players (the arrows of the game list and of the profiles)
        $leaguesScores = $currentPeriod
            ? $scoreService->getLeagueScoresForPromotion($game, $currentPeriod->id)->map(fn (array $leagueScore) => Arr::except($leagueScore, 'promoted_user_ids'))
            : collect();
        // nobody played in the league yet: any score with the stars is enough
        if ($league && !$leaguesScores->has($league->id) && $leagueService->canBePromotedAlone($game, $currentPeriod, $league)) {
            $leaguesScores = $leaguesScores->put($league->id, ['required_score' => null, 'active_players_count' => 0, 'promotion_slots' => 1]);
        }

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
        $games = Game::query()
            ->where('is_active', true)
            ->orderBy('name')
            ->get();
        $bestRuns = $scoreService->getBestRunsByGame($games);
        $records = $games->map(function (Game $game) use ($bestRuns) {
            $bestRun = $bestRuns->get($game->id);

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
        $user = Auth::user();
        $currentPeriod = Period::current()->first();
        $games = Game::query()
            ->where('is_active', true)
            ->orderBy('name')
            ->get();
        $scores = $scoreService->getUserBestScoresByGame($games, $user->id, $currentPeriod?->id);
        $leagues = $currentPeriod ? $leagueService->getCurrentLeaguesForGames($user, $games, $currentPeriod) : [];
        $records = $games->map(fn (Game $game) => [
            'game' => [
                'id' => $game->id,
                'name' => $game->name,
                'stars' => $game->stars,
            ],
            'score' => $scores[$game->id]['score'] ?? null,
            'current_score' => $currentPeriod === null ? null : ($scores[$game->id]['current_score'] ?? null),
            'league' => $currentPeriod === null ? null : $leagues[$game->id],
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

    // the ranking V1 of a period, COMPETITION_PER_PAGE players a page, and the line of the player wherever they are
    public function competition(Request $request, ScoreService $scoreService)
    {
        $request->validate([
            'period' => 'sometimes|required|integer|exists:periods,id',
            'page' => 'sometimes|required|integer|min:1',
        ]);
        $currentPeriod = Period::current()->first();
        $selectedPeriod = $request->has('period')
            ? Period::findOrFail($request->integer('period'))
            : $currentPeriod;

        // every player is ranked to know the rank of each one: the ranking is kept a minute (an hour for a closed period)
        $periodId = $selectedPeriod?->id;
        $ranking = Cache::remember(
            'competition:'.($periodId ?? 'none'),
            $periodId !== null && $periodId === $currentPeriod?->id ? 60 : 3600,
            fn () => $scoreService->get1500Leaderboard($periodId)->all(),
        );

        $total = count($ranking);
        $lastPage = max(1, (int) ceil($total / self::COMPETITION_PER_PAGE));
        $page = min($request->integer('page', 1), $lastPage);
        $etwinId = $request->user()->etwin_id;

        return response()->json([
            'data' => array_slice($ranking, ($page - 1) * self::COMPETITION_PER_PAGE, self::COMPETITION_PER_PAGE),
            'meta' => ['current_page' => $page, 'last_page' => $lastPage, 'per_page' => self::COMPETITION_PER_PAGE, 'total' => $total],
            'me' => collect($ranking)->first(fn (array $player) => $player['user']['etwin_id'] === $etwinId),
        ]);
    }

    public function poidsPlumes(Request $request, PoidsPlumeService $poidsPlumeService)
    {
        $request->validate([
            'period' => 'sometimes|required|integer|exists:periods,id',
        ]);
        $selectedPeriod = $request->has('period')
            ? Period::findOrFail($request->integer('period'))
            : Period::current()->first();

        return response()->json($poidsPlumeService->getLeaderboardForPeriod($selectedPeriod));
    }

    public function search(Request $request, Game $game, ScoreService $scoreService)
    {
        Gate::authorize('view', $game);
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

        // without the replays (the ones of today's daily game are shown the next day), nor their data: the columns read
        // by RunResource only
        $dailyGameRuns = $dailyGame?->runs()
            ->select(['id', 'user_id', 'game_id', 'daily_game_id', 'score', 'contract_score', 'contract_points', 'play_time_seconds', 'period_id', 'league_id', 'completed_at', 'views_count', 'comments_count', 'is_cheat'])
            ->whereNotNull('score')
            ->where('is_cheat', false)
            ->orderByDesc('score')
            ->with('user')
            ->limit(10)
            ->get() ?? collect();

        $myPosition = $scoreService->getUserPositionOnDailyGame($dailyGame, Auth::id());

        return RunResource::collection($dailyGameRuns)
            ->additional([
                'position' => $myPosition,
            ]);
    }
}
