<?php

namespace App\Events;

use App\Support\Realtime;
use Illuminate\Broadcasting\Channel;

// the daily game of today chosen (kado:prepare-daily-game)
class DailyGameStarted extends RealtimeEvent
{
    public function broadcastOn(): Channel
    {
        return Realtime::site();
    }

    public function broadcastAs(): string
    {
        return 'daily.started';
    }

    // once by request
    public function dedupeKey(): ?string
    {
        return '';
    }
}
