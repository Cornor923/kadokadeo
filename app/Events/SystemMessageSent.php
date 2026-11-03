<?php

namespace App\Events;

use App\Support\Realtime;
use Illuminate\Broadcasting\Channel;

// a message of the site to every player (App\Services\MessageService::systemToAll): one event for all, each page reloads
// its counters (not all at the same moment)
class SystemMessageSent extends RealtimeEvent
{
    public function broadcastOn(): Channel
    {
        return Realtime::site();
    }

    public function broadcastAs(): string
    {
        return 'messages.refresh';
    }

    // once by request
    public function dedupeKey(): ?string
    {
        return '';
    }
}
