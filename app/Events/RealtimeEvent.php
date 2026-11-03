<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;

// an event of the realtime of the site, sent by App\Support\Realtime::send after the response. Not queued: the only worker
// also verifies the replays (minutes in a browser), the events would wait behind them. Listened by the front as
// ".<broadcastAs()>"
abstract class RealtimeEvent implements ShouldBroadcastNow
{
    /** @return Channel|Channel[] */
    abstract public function broadcastOn(): Channel|array;

    abstract public function broadcastAs(): string;

    /** @return array<string, mixed> */
    public function broadcastWith(): array
    {
        return [];
    }

    // the events of a request with the same class and key are sent once (App\Support\RealtimeOutbox): the last one,
    // merged with the one before. null: each is sent
    public function dedupeKey(): ?string
    {
        return null;
    }

    public function mergedWith(self $earlier): self
    {
        return $this;
    }
}
