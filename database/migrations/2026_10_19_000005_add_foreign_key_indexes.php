<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

// PostgreSQL does not index the foreign keys: the rows read by them, and the rows checked when a run or a clan is
// deleted (a run deleted read replay_verifications, league_promotions, clan_attacks and clan_mission_steps entirely).
// Built CONCURRENTLY on PostgreSQL (it can't run in a transaction). If it fails, PostgreSQL leaves an INVALID index of
// this name: drop it before migrating again
return new class() extends Migration
{
    public $withinTransaction = false;

    // table => [index name => columns]
    private const INDEXES = [
        'replay_verifications' => ['replay_verifications_run_id_index' => ['run_id']],
        'league_promotions' => ['league_promotions_run_id_index' => ['run_id']],
        'clan_attacks' => [
            'clan_attacks_run_id_index' => ['run_id'],
            'clan_attacks_defense_run_id_index' => ['defense_run_id'],
        ],
        'clan_mission_steps' => [
            'clan_mission_steps_clan_mission_id_index' => ['clan_mission_id'],
            'clan_mission_steps_run_id_index' => ['run_id'],
        ],
        'runs' => ['runs_game_build_id_index' => ['game_build_id']],
        // the points of a player, the points given by a run (taken back from a cheated run)
        'user_points' => [
            'user_points_user_id_index' => ['user_id'],
            'user_points_source_type_source_id_index' => ['source_type', 'source_id'],
        ],
        'run_comments' => ['run_comments_parent_id_index' => ['parent_id']],
        // the members of a clan (counted on most clan pages)
        'clan_members' => ['clan_members_clan_id_index' => ['clan_id']],
        // the pending applications of a player (the clan overview)
        'clan_applications' => ['clan_applications_user_id_status_index' => ['user_id', 'status']],
        // the favorite games of a player (the unique index starts with game_id)
        'user_favorite_games' => ['user_favorite_games_user_id_index' => ['user_id']],
    ];

    public function up(): void
    {
        foreach (self::INDEXES as $table => $indexes) {
            foreach ($indexes as $name => $columns) {
                if (DB::getDriverName() === 'pgsql') {
                    DB::statement(sprintf('CREATE INDEX CONCURRENTLY IF NOT EXISTS %s ON %s (%s)', $name, $table, implode(', ', $columns)));
                } else {
                    Schema::table($table, fn (Blueprint $t) => $t->index($columns, $name));
                }
            }
        }
    }

    public function down(): void
    {
        foreach (self::INDEXES as $table => $indexes) {
            foreach (array_keys($indexes) as $name) {
                if (DB::getDriverName() === 'pgsql') {
                    DB::statement("DROP INDEX CONCURRENTLY IF EXISTS {$name}");
                } else {
                    Schema::table($table, fn (Blueprint $t) => $t->dropIndex($name));
                }
            }
        }
    }
};
