<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

// the "Jeu caca" and "Jeu cool" of a clan are lists: each option used keeps its game (instead of a single game of each in
// clan_period_scores). A game is in one list at most, once.
return new class() extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('clan_bonuses', function (Blueprint $table) {
            $table->foreignId('game_id')->nullable()->constrained('games')->nullOnDelete();
            $table->unique(['clan_id', 'period_id', 'game_id']);
        });

        // the games already chosen: on the last option of their kind used during the period
        $columns = ['banned_game_id' => 'ban_game', 'forced_game_id' => 'force_game'];
        foreach (DB::table('clan_period_scores')->whereNotNull('banned_game_id')->orWhereNotNull('forced_game_id')->get() as $score) {
            foreach ($columns as $column => $type) {
                if ($score->{$column} === null || DB::table('clan_bonuses')->where('clan_id', $score->clan_id)->where('period_id', $score->period_id)->where('game_id', $score->{$column})->exists()) {
                    continue;
                }
                $bonusId = DB::table('clan_bonuses')
                    ->where('clan_id', $score->clan_id)
                    ->where('period_id', $score->period_id)
                    ->where('type', $type)
                    ->whereNotNull('used_at')
                    ->orderByDesc('used_at')
                    ->value('id');
                if ($bonusId) {
                    DB::table('clan_bonuses')->where('id', $bonusId)->update(['game_id' => $score->{$column}]);
                }
            }
        }

        Schema::table('clan_period_scores', function (Blueprint $table) {
            $table->dropConstrainedForeignId('banned_game_id');
            $table->dropConstrainedForeignId('forced_game_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('clan_period_scores', function (Blueprint $table) {
            $table->foreignId('banned_game_id')->nullable()->constrained('games')->nullOnDelete();
            $table->foreignId('forced_game_id')->nullable()->constrained('games')->nullOnDelete();
        });

        // the last game of each list
        $columns = ['ban_game' => 'banned_game_id', 'force_game' => 'forced_game_id'];
        foreach (DB::table('clan_bonuses')->whereNotNull('game_id')->orderBy('used_at')->get() as $bonus) {
            if (isset($columns[$bonus->type])) {
                DB::table('clan_period_scores')
                    ->where('clan_id', $bonus->clan_id)
                    ->where('period_id', $bonus->period_id)
                    ->update([$columns[$bonus->type] => $bonus->game_id]);
            }
        }

        Schema::table('clan_bonuses', function (Blueprint $table) {
            $table->dropUnique(['clan_id', 'period_id', 'game_id']);
            $table->dropConstrainedForeignId('game_id');
        });
    }
};
