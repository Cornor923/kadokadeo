<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\RunResource;
use App\Http\Resources\UserResource;
use App\Models\Game;
use App\Models\Period;
use App\Models\User;
use App\Services\ClanService;
use App\Services\GameService;
use App\Services\LeagueService;
use App\Services\PeriodSummaryService;
use App\Services\ScoreService;
use App\Settings\ClanSettings;
use App\Settings\SiteSettings;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class UserController extends Controller implements \Illuminate\Routing\Controllers\HasMiddleware
{
    public static function middleware()
    {
        return [
            new \Illuminate\Routing\Controllers\Middleware('auth:sanctum', only: ['index', 'show', 'showPeriod']),
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

        if (app(SiteSettings::class)->achievements_enabled) {
            $user->load('achievementProgress');
        }

        return UserResource::make($user);
    }

    /**
     * Profile of a user. If no user is provided, it will return the profile of the authenticated user.
     */
    public function show(?User $user, ScoreService $scoreService, LeagueService $leagueService, GameService $gameService, ClanService $clanService)
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
            'clan' => $this->profileClan($user, $clanService),
            'achievements' => app(SiteSettings::class)->achievements_enabled
                ? $user->achievementProgress->map(function ($progress) {
                    return [
                        'achievement_id' => $progress->achievement_id,
                        'completed_level' => $progress->completed_level,
                    ];
                })
                : [],
        ]);
    }

    // the clan of the player shown on his profile, with his rank in it; none while the clans are off
    private function profileClan(User $user, ClanService $clanService): ?array
    {
        if (!app(ClanSettings::class)->enabled) {
            return null;
        }
        $clan = $clanService->clanOf($user);
        if (!$clan) {
            return null;
        }
        $role = $clanService->roleOf($user, $clan);

        return [
            'id' => $clan->id,
            'name' => $clan->name,
            'role' => $role?->value,
            'role_label' => $role?->getLabel(),
        ];
    }

    /**
     * The summary of a finished period of a player (its Kado points, its stars, its rankings): the last one when no
     * period is given; null when no period is finished yet.
     */
    public function showPeriod(User $user, PeriodSummaryService $periodSummaryService, ?Period $period = null)
    {
        $period ??= $periodSummaryService->lastFinishedPeriod();
        if (!$period) {
            return response()->json(['data' => null]);
        }
        abort_unless($periodSummaryService->isFinished($period), 404);

        $summary = $periodSummaryService->summary($user, $period);
        $summary['rankings'] = RunResource::collection($summary['rankings']);

        return response()->json(['data' => $summary]);
    }

    public function showHistory(User $user, Request $request)
    {
        $runsQuery = $user->runs()
            ->withoutReplay()
            ->whereNotNull('score')
            ->with('game')
            ->orderByDesc('completed_at');

        $runs = $runsQuery->paginate(20);

        return RunResource::collection($runs);
    }
}
