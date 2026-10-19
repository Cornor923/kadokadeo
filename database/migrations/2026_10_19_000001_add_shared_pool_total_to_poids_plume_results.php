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
        // kado points shared between the players with at least 2 feathers who did not win the jackpot
        Schema::table('poids_plume_results', function (Blueprint $table) {
            $table->unsignedBigInteger('shared_pool_total')->default(0)->after('jackpot_total');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('poids_plume_results', function (Blueprint $table) {
            $table->dropColumn('shared_pool_total');
        });
    }
};
