<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

// the runs not finished of a player, counted at each beginning of a run (App\Http\Requests\RunStartRequest): no index of
// runs starts with user_id. Partial on PostgreSQL (the finished runs are not in it: a small index). Built CONCURRENTLY
// (it can't run in a transaction). If it fails, PostgreSQL leaves an INVALID index of this name: drop it before
// migrating again
return new class() extends Migration
{
    public $withinTransaction = false;

    public function up(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement('CREATE INDEX CONCURRENTLY IF NOT EXISTS runs_open_user_id_created_at_index ON runs (user_id, created_at) WHERE completed_at IS NULL');

            return;
        }

        Schema::table('runs', function (Blueprint $table) {
            $table->index(['user_id', 'created_at'], 'runs_open_user_id_created_at_index');
        });
    }

    public function down(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement('DROP INDEX CONCURRENTLY IF EXISTS runs_open_user_id_created_at_index');

            return;
        }

        Schema::table('runs', function (Blueprint $table) {
            $table->dropIndex('runs_open_user_id_created_at_index');
        });
    }
};
