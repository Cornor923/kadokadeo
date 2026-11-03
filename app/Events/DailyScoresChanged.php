<?php

namespace App\Events;

use App\Support\Realtime;
use Illuminate\Broadcasting\Channel;

// the top of the daily game changed: its page reloads it
class DailyScoresChanged extends RealtimeEvent
{
    public function __construct(private readonly int $dailyGameId) {}

    public function broadcastOn(): Channel
    {
        return Realtime::daily();
    }

    public function broadcastAs(): string
    {
        return 'scores.changed';
    }

    public function broadcastWith(): array
    {
        return ['daily_game_id' => $this->dailyGameId];
    }

    public function dedupeKey(): ?string
    {
        return (string) $this->dailyGameId;
    }
}
