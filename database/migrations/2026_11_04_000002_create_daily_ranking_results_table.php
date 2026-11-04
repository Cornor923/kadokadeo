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
        // the daily ranking of a period when it closed, and what each player earned (App\Services\DailyRankingService)
        Schema::create('daily_ranking_results', function (Blueprint $table) {
            $table->id();
            $table->foreignId('period_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->unsignedInteger('rank_position');
            $table->unsignedInteger('points');
            $table->unsignedBigInteger('reward');
            $table->foreignId('user_point_id')->nullable()->constrained('user_points')->nullOnDelete();
            $table->timestamps();

            $table->unique(['period_id', 'user_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('daily_ranking_results');
    }
};
