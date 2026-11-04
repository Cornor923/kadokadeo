<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class() extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // the cron and the pages asking the game at midnight could each create the game of the day: the first one stays.
        // The runs of another game than the one kept are no longer daily runs (their scores cannot be compared)
        $days = DB::table('daily_games')
            ->select('day')
            ->selectRaw('MIN(id) AS kept_id')
            ->groupBy('day')
            ->havingRaw('COUNT(*) > 1')
            ->get();

        foreach ($days as $day) {
            $keptGameId = DB::table('daily_games')->where('id', $day->kept_id)->value('game_id');
            $others = DB::table('daily_games')->where('day', $day->day)->where('id', '!=', $day->kept_id)->pluck('id');

            DB::table('runs')->whereIn('daily_game_id', $others)->where('game_id', $keptGameId)->update(['daily_game_id' => $day->kept_id]);
            DB::table('runs')->whereIn('daily_game_id', $others)->update(['daily_game_id' => null]);
            DB::table('daily_games')->whereIn('id', $others)->delete();
        }

        Schema::table('daily_games', function (Blueprint $table) {
            $table->dropIndex(['day']);
            $table->unique('day');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('daily_games', function (Blueprint $table) {
            $table->dropUnique(['day']);
            $table->index('day');
        });
    }
};
