<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class() extends Migration
{
    public function up(): void
    {
        Schema::create('league_promotions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('period_id')->constrained('periods')->cascadeOnDelete();
            $table->foreignId('next_period_id')->constrained('periods')->cascadeOnDelete();
            $table->foreignId('game_id')->constrained('games')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('from_league_id')->constrained('leagues')->cascadeOnDelete();
            $table->foreignId('to_league_id')->constrained('leagues')->cascadeOnDelete();
            $table->foreignUlid('run_id')->nullable()->constrained('runs')->nullOnDelete();
            $table->unsignedInteger('rank_position');
            $table->unsignedBigInteger('score');
            $table->unsignedInteger('play_time_seconds')->nullable();
            $table->unsignedInteger('promotion_slots');
            $table->unsignedInteger('active_players_count');
            $table->unsignedBigInteger('promotion_reward')->default(0);
            $table->foreignId('user_point_id')->nullable()->constrained('user_points')->nullOnDelete();
            $table->timestamps();

            $table->unique(['period_id', 'game_id', 'user_id']);
            $table->index(['period_id', 'game_id', 'from_league_id']);
        });

        Schema::create('poids_plume_results', function (Blueprint $table) {
            $table->id();
            $table->foreignId('period_id')->constrained('periods')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->json('game_ids');
            $table->unsignedInteger('feathers_count');
            $table->unsignedBigInteger('jackpot_total')->default(0);
            $table->unsignedBigInteger('reward')->default(0);
            $table->foreignId('user_point_id')->nullable()->constrained('user_points')->nullOnDelete();
            $table->timestamps();

            $table->unique(['period_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('poids_plume_results');
        Schema::dropIfExists('league_promotions');
    }
};
