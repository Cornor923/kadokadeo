<?php

namespace App\Support;

use App\Events\DailyScoresChanged;
use App\Events\GameScoresChanged;
use App\Models\Run;

// the leaderboards shown by the pages (the side of a game, the daily game) told they changed (App\Support\Realtime)
class ScoreBoards
{
    // a run in their top, or taken out of them (cheat, deleted, restored)
    public static function changed(Run $run, bool $worldBest = false, bool $daily = true): void
    {
        Realtime::send(new GameScoresChanged($run->game_id, $run->period_id, $run->league_id, $worldBest));
        if ($daily && $run->daily_game_id) {
            Realtime::send(new DailyScoresChanged($run->daily_game_id));
        }
    }
}
