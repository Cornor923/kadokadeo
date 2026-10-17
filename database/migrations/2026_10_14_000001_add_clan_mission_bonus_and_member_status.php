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
        // the mission that won the option (none for the "Jeu cool" and "Jeu caca" given at the start of the period)
        Schema::table('clan_bonuses', function (Blueprint $table) {
            $table->foreignId('clan_mission_id')->nullable()->constrained('clan_missions')->nullOnDelete();
        });

        // the status of a member in the list of the members ("dispo le soir"...), seen by the clan only
        Schema::table('clan_members', function (Blueprint $table) {
            $table->string('status', 60)->nullable();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('clan_members', function (Blueprint $table) {
            $table->dropColumn('status');
        });
        Schema::table('clan_bonuses', function (Blueprint $table) {
            $table->dropConstrainedForeignId('clan_mission_id');
        });
    }
};
