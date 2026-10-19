<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

// the indexes of the rankings, read at each end of a run and on the pages of the games:
// - the daily game (its leaderboard, the position of the player, playDaily at each daily run)
// - the leaderboard of a league (ScoreService::getLeaderBoard, countPlayersAbove) and the scores of a period
//   (/competition, the period close)
// - the stars of a player in a period: one row by game and star, unique (two runs finished at once counted it twice:
//   the duplicates are removed, the counters of their players recounted)
// Built CONCURRENTLY on PostgreSQL: the runs are still written meanwhile (it can't run in a transaction). If it fails,
// PostgreSQL leaves an INVALID index of this name: drop it before migrating again
return new class() extends Migration
{
    public $withinTransaction = false;

    private const STAR_COLUMNS = [0 => 'green_stars', 1 => 'orange_stars', 2 => 'red_stars', 3 => 'purple_stars'];

    public function up(): void
    {
        $this->removeDuplicateStars();

        if (DB::getDriverName() === 'pgsql') {
            DB::statement('CREATE INDEX CONCURRENTLY IF NOT EXISTS runs_daily_game_id_score_index ON runs (daily_game_id, score DESC) WHERE daily_game_id IS NOT NULL');
            DB::statement('CREATE INDEX CONCURRENTLY IF NOT EXISTS runs_leaderboard_index ON runs (game_id, period_id, league_id, score DESC, user_id) WHERE score IS NOT NULL AND deleted_at IS NULL');
            DB::statement('CREATE INDEX CONCURRENTLY IF NOT EXISTS runs_period_scores_index ON runs (period_id, game_id, user_id) INCLUDE (score, is_cheat) WHERE score IS NOT NULL AND deleted_at IS NULL');
            DB::statement('CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS game_period_stars_unique ON game_period_stars (user_id, period_id, game_id, star)');

            return;
        }

        Schema::table('runs', function (Blueprint $table) {
            $table->index(['daily_game_id', 'score'], 'runs_daily_game_id_score_index');
            $table->index(['game_id', 'period_id', 'league_id', 'score', 'user_id'], 'runs_leaderboard_index');
            $table->index(['period_id', 'game_id', 'user_id'], 'runs_period_scores_index');
        });
        Schema::table('game_period_stars', function (Blueprint $table) {
            $table->unique(['user_id', 'period_id', 'game_id', 'star'], 'game_period_stars_unique');
        });
    }

    public function down(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            foreach (['runs_daily_game_id_score_index', 'runs_leaderboard_index', 'runs_period_scores_index', 'game_period_stars_unique'] as $index) {
                DB::statement("DROP INDEX CONCURRENTLY IF EXISTS {$index}");
            }

            return;
        }

        Schema::table('runs', function (Blueprint $table) {
            $table->dropIndex('runs_daily_game_id_score_index');
            $table->dropIndex('runs_leaderboard_index');
            $table->dropIndex('runs_period_scores_index');
        });
        Schema::table('game_period_stars', function (Blueprint $table) {
            $table->dropUnique('game_period_stars_unique');
        });
    }

    // the first row of each star is kept; the counters of user_stars (incremented for each row) are recounted for the
    // players who had duplicates
    private function removeDuplicateStars(): void
    {
        $duplicates = DB::table('game_period_stars')
            ->select('user_id', 'period_id', 'game_id', 'star', DB::raw('MIN(id) AS kept_id'))
            ->groupBy('user_id', 'period_id', 'game_id', 'star')
            ->havingRaw('COUNT(*) > 1')
            ->get();

        foreach ($duplicates as $duplicate) {
            DB::table('game_period_stars')
                ->where('user_id', $duplicate->user_id)
                ->where('period_id', $duplicate->period_id)
                ->where('game_id', $duplicate->game_id)
                ->where('star', $duplicate->star)
                ->where('id', '!=', $duplicate->kept_id)
                ->delete();
        }

        foreach ($duplicates->unique(fn ($d) => "{$d->user_id}-{$d->period_id}") as $duplicate) {
            $counts = DB::table('game_period_stars')
                ->where('user_id', $duplicate->user_id)
                ->where('period_id', $duplicate->period_id)
                ->select('star', DB::raw('COUNT(*) AS stars'))
                ->groupBy('star')
                ->pluck('stars', 'star');
            DB::table('user_stars')
                ->where('user_id', $duplicate->user_id)
                ->where('period_id', $duplicate->period_id)
                ->update(collect(self::STAR_COLUMNS)->mapWithKeys(fn ($column, $star) => [$column => (int) ($counts[$star] ?? 0)])->all());
        }
    }
};
