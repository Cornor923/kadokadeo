<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// the "Double points" option: used, it waits for the next mission of the clan (clan_bonuses.doubled_mission_id null), which
// then gives twice its points when it is completed
return new class() extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('clan_missions', function (Blueprint $table) {
            $table->boolean('double_points')->default(false);
        });
        Schema::table('clan_bonuses', function (Blueprint $table) {
            $table->foreignId('doubled_mission_id')->nullable()->constrained('clan_missions')->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('clan_bonuses', function (Blueprint $table) {
            $table->dropConstrainedForeignId('doubled_mission_id');
        });
        Schema::table('clan_missions', function (Blueprint $table) {
            $table->dropColumn('double_points');
        });
    }
};
