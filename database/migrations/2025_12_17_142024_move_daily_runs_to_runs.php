<?php

use App\Models\Run;
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
        Schema::table('runs', function (Blueprint $table) {
            $table->foreignId('daily_game_id')->nullable()->constrained('daily_games')->nullOnDelete();
        });

        \App\Models\DailyGame::chunk(10, function ($dailyGames) {
            foreach ($dailyGames as $dailyGame) {
                Run::withTrashed()
                    ->leftJoin('daily_game_runs', 'runs.id', '=', 'daily_game_runs.run_id')
                    ->where('daily_game_runs.daily_game_id', $dailyGame->id)
                    ->update(['runs.daily_game_id' => $dailyGame->id]);
            }
        });

        Schema::dropIfExists('daily_game_runs');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void {}
};
