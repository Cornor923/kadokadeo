<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

// the rankings of a game in a period and a league (ScoreService::getLeaderBoard: the period close, the poids plumes, the
// pages of the games) read all the runs of the game without it. Built CONCURRENTLY on PostgreSQL: the runs are still
// written meanwhile (it can't run in a transaction). If it fails, PostgreSQL leaves an INVALID index of this name: drop
// it before migrating again
return new class() extends Migration
{
    public $withinTransaction = false;

    public function up(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement('CREATE INDEX CONCURRENTLY IF NOT EXISTS runs_game_id_period_id_league_id_index ON runs (game_id, period_id, league_id)');

            return;
        }

        Schema::table('runs', function (Blueprint $table) {
            $table->index(['game_id', 'period_id', 'league_id']);
        });
    }

    public function down(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement('DROP INDEX CONCURRENTLY IF EXISTS runs_game_id_period_id_league_id_index');

            return;
        }

        Schema::table('runs', function (Blueprint $table) {
            $table->dropIndex(['game_id', 'period_id', 'league_id']);
        });
    }
};
