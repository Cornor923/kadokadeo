<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class() extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // the free games of the attacks and defenses left today (App\Settings\ClanSettings::$attack_games_per_day, given
        // again by kado:reset-daily-games), apart from the games of the day of the normal runs
        Schema::table('users', function (Blueprint $table) {
            $table->unsignedInteger('clan_attack_games')->default(0);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('clan_attack_games');
        });
    }
};
