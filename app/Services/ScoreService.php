<?php

namespace App\Services;

use App\Models\DailyGame;
use App\Models\Game;
use App\Models\LeagueMembership;
use App\Models\Run;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class ScoreService
{
    public function __construct() {}

    public function getLeaderBoard(Game $game, ?int $periodId = null, ?int $leagueId = null): Builder
    {
        $rankedBestRuns = DB::query()
            ->fromSub($this->getBestRunsPerUserSubquery($game, $periodId, $leagueId), 'best_runs')
            ->where('best_runs.user_run_rank', 1)
            ->select('best_runs.*')
            ->selectRaw('ROW_NUMBER() OVER (ORDER BY best_runs.score DESC, best_runs.play_time_seconds ASC, best_runs.completed_at ASC, best_runs.id ASC) AS rank_position');

        return Run::query()
            ->fromSub($rankedBestRuns, 'runs')
            ->with('user')
            ->select(
                'runs.id',
                'runs.period_id',
                'runs.game_id',
                'runs.user_id',
                'runs.league_id',
                'runs.score',
                'runs.play_time_seconds',
                'runs.rank_position',
                'runs.daily_game_id',
                DB::raw('CASE WHEN runs.replay IS NULL THEN NULL ELSE 1 END as replay')
            )
            ->orderByDesc('runs.score')
            ->orderBy('runs.play_time_seconds')
            ->orderBy('runs.completed_at')
            ->orderBy('runs.id');
    }

    public function getUserBestScore(Game $game, ?int $userId, ?int $periodId = null): ?Run
    {
        return $game->runs()
            ->whereNotNull('score')
            ->where('is_cheat', false)
            ->when($periodId, fn ($q) => $q->where('period_id', $periodId))
            ->when($userId, fn ($q) => $q->where('user_id', $userId))
            ->orderBy('score', 'desc')
            ->orderBy('play_time_seconds')
            ->orderBy('completed_at')
            ->orderBy('id')
            ->first();
    }

    public function getBestScore(Game $game, ?int $userId, ?int $periodId = null): ?Run
    {
        return $game->runs()
            ->whereNotNull('score')
            ->where('is_cheat', false)
            ->when($periodId, fn ($q) => $q->where('period_id', $periodId))
            ->orderBy('score', 'desc')
            ->orderBy('play_time_seconds')
            ->orderBy('completed_at')
            ->orderBy('id')
            ->first();
    }

    public function getUserBestScoresByPeriod(Game $game, int $userId): Collection
    {
        return $game->runs()
            ->select('period_id')
            ->selectRaw('MAX(score) as score')
            ->where('user_id', $userId)
            ->whereNotNull('score')
            ->where('is_cheat', false)
            ->groupBy('period_id')
            ->pluck('score', 'period_id');
    }

    public function get1500Leaderboard(?int $periodId): Collection
    {
        $bestScores = collect();
        if ($periodId !== null) {
            $bestScores = Run::query()
                ->whereHas('game', fn (Builder $query) => $query->where('is_active', true))
                ->where('period_id', $periodId)
                ->select('user_id', 'game_id')
                ->selectRaw('MAX(score) as score')
                ->whereNotNull('score')
                ->where('is_cheat', false)
                ->groupBy('user_id', 'game_id')
                ->get();
        }

        $games = Game::query()
            ->whereIn('id', $bestScores->pluck('game_id')->unique())
            ->get(['id', 'name', 'stars', 'score_rankv1'])
            ->keyBy('id');

        $playerScores = $bestScores->groupBy('user_id')->map(function (Collection $scores) use ($games) {
            return $scores
                ->map(fn ($score) => [
                    'game' => [
                        'id' => (int) $score->game_id,
                        'name' => $games->get($score->game_id)?->name ?? '',
                    ],
                    'score' => $this->calculateScoreOn1500(
                        (int) $score->score,
                        $games->get($score->game_id)?->stars ?? [],
                        $games->get($score->game_id)?->score_rankv1,
                    ),
                ])
                ->sort(fn ($left, $right) => $right['score'] <=> $left['score'])
                ->take(12)
                ->values();
        });

        return User::query()
            ->get(['id', 'etwin_id', 'display_name'])
            ->map(fn (User $user) => [
                'user' => [
                    'etwin_id' => $user->etwin_id,
                    'display_name' => $user->display_name,
                ],
                'score' => $playerScores->get($user->id, collect())->sum('score'),
                'games' => $playerScores->get($user->id, collect())->map(fn ($gameScore) => [
                    'game' => $gameScore['game'],
                    'score' => $gameScore['score'],
                ]),
            ])
            ->filter(fn ($player) => $player['score'] > 0)
            ->sort(fn ($leftPlayer, $rightPlayer) => ($rightPlayer['score'] <=> $leftPlayer['score'])
                ?: strcasecmp($leftPlayer['user']['display_name'], $rightPlayer['user']['display_name']))
            ->values()
            ->map(fn ($player, $index) => ['rank' => $index + 1] + $player);
    }

    public function calculateScoreOn1500(int $score, array $thresholds, ?int $scoreRankV1 = null): int
    {
        if (count($thresholds) < 3) {
            return 0;
        }

        [$green, $orange, $red] = array_map('floatval', array_slice($thresholds, 0, 3));

        if ($green <= 0 || $orange <= $green || $red <= $orange || $scoreRankV1 === null || $scoreRankV1 <= $red || $score <= 0) {
            return 0;
        }

        if ($score <= $green) {
            $points = ($score / $green) * 1000;
        } elseif ($score <= $orange) {
            $points = 1000 + (($score - $green) / ($orange - $green)) * 100;
        } elseif ($score <= $red) {
            $points = 1100 + (($score - $orange) / ($red - $orange)) * 50;
        } else {
            $points = 1150 + (($score - $red) / ($scoreRankV1 - $red)) * 350;
        }

        return (int) round(min($points, 1500));
    }

    private function getBestRunsPerUserSubquery(Game $game, ?int $periodId = null, ?int $leagueId = null): Builder
    {
        return Run::query()
            ->select('runs.*')
            ->selectRaw('ROW_NUMBER() OVER (PARTITION BY runs.user_id ORDER BY runs.score DESC, runs.play_time_seconds ASC, runs.completed_at ASC, runs.id ASC) AS user_run_rank')
            ->where('runs.game_id', $game->id)
            ->whereNotNull('runs.score')
            ->where('runs.is_cheat', false)
            ->when($periodId, fn ($query) => $query->where('runs.period_id', $periodId))
            ->when($leagueId, fn ($query) => $query->where('runs.league_id', $leagueId));
    }

    public function getUserBestRuns(User $user, ?int $periodId = null): Collection
    {
        $userLeagues = LeagueMembership::query()
            ->select('game_id', 'league_id')
            ->where('user_id', $user->id)
            ->when($periodId, fn ($query) => $query->where('period_id', $periodId))
            ->distinct();

        $bestRunsPerUser = Run::query()
            ->select('runs.*')
            ->selectRaw('
                ROW_NUMBER() OVER (
                    PARTITION BY runs.game_id, runs.user_id
                    ORDER BY
                        runs.score DESC,
                        runs.play_time_seconds ASC,
                        runs.completed_at ASC,
                        runs.id ASC
                ) AS user_best_rank
            ')
            ->joinSub($userLeagues, 'user_leagues', function ($join) {
                $join->on('runs.game_id', '=', 'user_leagues.game_id')
                    ->on('runs.league_id', '=', 'user_leagues.league_id');
            })
            ->whereNotNull('runs.score')
            ->where('runs.is_cheat', false)
            ->when($periodId, fn ($query) => $query->where('runs.period_id', $periodId))
            ->whereNull('runs.deleted_at');

        $rankedBestRuns = DB::query()
            ->fromSub($bestRunsPerUser, 'best_runs')
            ->where('best_runs.user_best_rank', 1)
            ->select('best_runs.*')
            ->selectRaw('
                ROW_NUMBER() OVER (
                    PARTITION BY best_runs.game_id
                    ORDER BY
                        best_runs.score DESC,
                        best_runs.play_time_seconds ASC,
                        best_runs.completed_at ASC,
                        best_runs.id ASC
                ) AS league_rank
            ')
            ->when($periodId, fn ($query) => $query->where('best_runs.period_id', $periodId));

        $r = DB::query()
            ->fromSub($rankedBestRuns, 'user_best_runs')
            ->select([
                'user_best_runs.*',
                'league_rank',
            ])
            ->where('user_id', $user->id)
            ->orderBy('game_id')
            ->get();

        return Run::hydrate($r->toArray());
    }

    public function getUserPositionOnDailyGame(DailyGame $game, int $userId): ?int
    {
        $bestRunsPerUser = Run::query()
            ->select('runs.*')
            ->selectRaw('ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY score DESC, play_time_seconds ASC, completed_at ASC, id ASC) AS user_best_rank')
            ->whereNotNull('score')
            ->where('is_cheat', false)
            ->where('daily_game_id', $game->id);

        $rankedBestRuns = DB::query()
            ->fromSub($bestRunsPerUser, 'best_runs')
            ->where('best_runs.user_best_rank', 1)
            ->select([
                'best_runs.user_id',
                DB::raw('ROW_NUMBER() OVER (ORDER BY best_runs.score DESC, best_runs.play_time_seconds ASC, best_runs.completed_at ASC, best_runs.id ASC ) AS rank_position'),
            ]);

        $result = DB::query()
            ->fromSub($rankedBestRuns, 'ranked')
            ->where('user_id', $userId)
            ->first();

        return $result?->rank_position;
    }

    public function getLeagueScoresForPromotion(Game $game, int $periodId)
    {
        return cache()->remember("promotion_scores_{$game->id}_{$periodId}", now()->addMinutes(10), function () use ($game, $periodId) {
            $bestRuns = Run::query()
                ->select('runs.*')
                ->selectRaw('ROW_NUMBER() OVER (PARTITION BY runs.league_id, runs.user_id ORDER BY runs.score DESC, runs.play_time_seconds ASC, runs.completed_at ASC, runs.id ASC) AS user_best_rank')
                ->where('runs.game_id', $game->id)
                ->where('runs.period_id', $periodId)
                ->whereNotNull('runs.score')
                ->where('runs.is_cheat', false)
                ->whereNotNull('runs.league_id')
                ->whereNull('runs.deleted_at');

            $rankedRuns = DB::query()
                ->fromSub($bestRuns, 'best_runs')
                ->where('best_runs.user_best_rank', 1)
                ->select('best_runs.*')
                ->selectRaw('ROW_NUMBER() OVER (PARTITION BY best_runs.league_id ORDER BY best_runs.score DESC, best_runs.play_time_seconds ASC, best_runs.completed_at ASC, best_runs.id ASC) AS league_rank')
                ->selectRaw('COUNT(*) OVER (PARTITION BY best_runs.league_id) AS active_players_count');

            $rows = DB::query()
                ->fromSub($rankedRuns, 'ranked_runs')
                ->join('leagues', 'leagues.id', '=', 'ranked_runs.league_id')
                ->join('leagues as next_leagues', 'next_leagues.level', '=', DB::raw('leagues.level + 1'))
                ->select([
                    'ranked_runs.league_id',
                    'ranked_runs.active_players_count',
                    'ranked_runs.league_rank',
                    'ranked_runs.score as required_score',
                ])
                ->selectRaw('CASE
                    WHEN leagues.promotion_ratio_divisor IS NOT NULL
                        AND leagues.promotion_max_slots IS NOT NULL
                        THEN LEAST(
                            CAST((ranked_runs.active_players_count + leagues.promotion_ratio_divisor - 1) / leagues.promotion_ratio_divisor AS INTEGER),
                            leagues.promotion_max_slots,
                            ranked_runs.active_players_count
                        )
                    WHEN leagues.promotion_ratio_divisor IS NOT NULL
                        THEN LEAST(
                            CAST((ranked_runs.active_players_count + leagues.promotion_ratio_divisor - 1) / leagues.promotion_ratio_divisor AS INTEGER),
                            ranked_runs.active_players_count
                        )
                    WHEN leagues.promotion_max_slots IS NOT NULL
                        THEN LEAST(leagues.promotion_max_slots, ranked_runs.active_players_count)
                    ELSE 0
                END AS promotion_slots')
                ->get()
                ->filter(fn ($row) => (int) $row->league_rank === (int) $row->promotion_slots)
                ->values();

            return $rows->mapWithKeys(function ($row) {
                return [$row->league_id => [
                    'required_score' => $row->required_score,
                    'active_players_count' => $row->active_players_count,
                    'promotion_slots' => $row->promotion_slots,
                ]];
            });
        });
    }
}
