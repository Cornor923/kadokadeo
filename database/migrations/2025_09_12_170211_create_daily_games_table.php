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
        Schema::create('daily_games', function (Blueprint $table) {
            $table->id();
            $table->date('day')->index();
            $table->foreignId('game_id')->constrained()->onDelete('cascade');
            $table->string('seed');
            $table->integer('contract_score');
            $table->integer('contract_points');
        });

        Schema::create('daily_game_runs', function (Blueprint $table) {
            $table->foreignId('daily_game_id')->constrained()->onDelete('cascade');
            $table->foreignUlid('run_id')->constrained()->onDelete('cascade');
            $table->primary(['daily_game_id', 'run_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('daily_game_runs');
        Schema::dropIfExists('daily_games');
    }
};
