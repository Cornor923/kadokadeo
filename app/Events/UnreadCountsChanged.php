<?php

namespace App\Events;

use App\Models\User;
use App\Support\Realtime;
use App\Support\Unread;
use Illuminate\Broadcasting\Channel;

// what the player has not read changed (read or deleted, maybe in another tab): his badge
class UnreadCountsChanged extends RealtimeEvent
{
    private readonly int $userId;

    public function __construct(User|int $user)
    {
        $this->userId = $user instanceof User ? $user->id : $user;
    }

    public function broadcastOn(): Channel
    {
        return Realtime::user($this->userId);
    }

    public function broadcastAs(): string
    {
        return 'unread';
    }

    public function broadcastWith(): array
    {
        return ['unread' => Unread::counts($this->userId)];
    }

    // read when sent: one for the player
    public function dedupeKey(): ?string
    {
        return (string) $this->userId;
    }
}
