<?php

namespace App\Events;

use App\Support\Realtime;
use Illuminate\Broadcasting\Channel;

// what the site knows of the player changed (his stars...): his pages read him again. On the channel of the site: every
// player (a new period, the games of the day given back), not all at the same moment
class UserRefresh extends RealtimeEvent
{
    // null: every player
    public function __construct(private readonly ?int $userId = null) {}

    public function broadcastOn(): Channel
    {
        return $this->userId ? Realtime::user($this->userId) : Realtime::site();
    }

    public function broadcastAs(): string
    {
        return 'user.refresh';
    }

    // one for the player (or all)
    public function dedupeKey(): ?string
    {
        return (string) $this->userId;
    }
}
