<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schema;

return new class() extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('leagues', function (Blueprint $table) {
            $table->id();
            $table->unsignedTinyInteger('level')->unique();
            $table->string('name');
            $table->unsignedBigInteger('promotion_max_slots')->nullable();
            $table->unsignedInteger('promotion_ratio_divisor')->nullable();
            $table->unsignedTinyInteger('promotion_min_stars')->nullable();
            $table->unsignedBigInteger('promotion_reward')->nullable();
            $table->timestamps();
        });

        Schema::table('runs', function (Blueprint $table) {
            $table->foreignId('league_id')->nullable()->constrained('leagues')->nullOnDelete();
        });

        Schema::create('league_memberships', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('period_id')->constrained('periods')->cascadeOnDelete();
            $table->foreignId('game_id')->constrained('games')->cascadeOnDelete();
            $table->foreignId('league_id')->constrained('leagues')->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['user_id', 'period_id', 'game_id']);
            $table->index(['period_id', 'game_id', 'league_id']);
        });

        Artisan::call('db:seed', [
            '--class' => 'LeagueSeeder',
            '--force' => true,
        ]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('league_memberships');

        Schema::table('runs', function (Blueprint $table) {
            $table->dropForeign(['league_id']);
            $table->dropColumn('league_id');
        });

        Schema::dropIfExists('leagues');
    }
};
