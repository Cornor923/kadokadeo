<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\RunResource;
use App\Http\Resources\UserResource;
use App\Models\Game;
use App\Models\Period;
use App\Models\User;
use App\Services\GameService;
use App\Services\LeagueService;
use App\Services\ScoreService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class UserController extends Controller implements \Illuminate\Routing\Controllers\HasMiddleware
{
    public static function middleware()
    {
        return [
            new \Illuminate\Routing\Controllers\Middleware('auth:sanctum', only: ['index', 'show']),
        ];
    }

    /**
     * Display the authenticated user.
     */
    public function index(Request $request)
    {
        $user = $request->user();

        $user->load([
            'stars' => fn ($query) => $query->where('period_id', Period::current()->first()?->id),
        ]);

        if (config('kado.achievements.enabled')) {
            $user->load('achievementProgress');
        }

        return UserResource::make($user);
    }

    /**
     * Profile of a user. If no user is provided, it will return the profile of the authenticated user.
     */
    public function show(?User $user, ScoreService $scoreService, LeagueService $leagueService, GameService $gameService)
    {
        if (!$user?->id) {
            $user = Auth::user();
        }
        $periodId = Period::current()->first()?->id;

        $stars = Game::select(['games.id', DB::raw('MAX(game_period_stars.star) as best_star')])
            ->leftJoin('game_period_stars', 'game_period_stars.game_id', '=', 'games.id')
            ->where('game_period_stars.user_id', $user->id)
            ->groupBy('games.id')
            ->get();

        $bestRuns = $scoreService->getUserBestRuns($user, $periodId)->keyBy('game_id');
        $bestRuns->load('game');
        $currentLeagues = $leagueService->getCurrentLeagues($user, $periodId);
        $maxStars = $gameService->getMaxStarsCount();

        return UserResource::make($user)->additional([
            'best_stars' => $stars->pluck('best_star', 'id'),
            'best_period_runs' => RunResource::collection($bestRuns),
            'current_leagues' => $currentLeagues,
            'promotion_game_ids' => $periodId ? $leagueService->getPromotionGameIds($user, $periodId) : [],
            'max_stars' => $maxStars,
            'achievements' => config('kado.achievements.enabled')
                ? $user->achievementProgress->map(function ($progress) {
                    return [
                        'achievement_id' => $progress->achievement_id,
                        'completed_level' => $progress->completed_level,
                    ];
                })
                : [],
        ]);
    }

    public function showHistory(User $user, Request $request)
    {
        $runsQuery = $user->runs()
            ->whereNotNull('score')
            ->with('game')
            ->orderByDesc('completed_at');

        $runs = $runsQuery->paginate(20);

        return RunResource::collection($runs);
    }
}
