<?php

namespace App\Events;

use App\Models\User;
use App\Support\Realtime;
use Illuminate\Broadcasting\Channel;

// the Kado points or the games of the player changed (a contract, a purchase, a reward, the admin...): his menus
class UserCountersChanged extends RealtimeEvent
{
    public const COUNTERS = ['kado_points', 'kado_games', 'clan_games', 'clan_attack_games'];

    public function __construct(private readonly int $userId) {}

    public function broadcastOn(): Channel
    {
        return Realtime::user($this->userId);
    }

    public function broadcastAs(): string
    {
        return 'user.counters';
    }

    // read when sent (after the transaction): the values of then
    public function broadcastWith(): array
    {
        return User::query()->whereKey($this->userId)->first(self::COUNTERS)?->only(self::COUNTERS) ?? [];
    }

    // read when sent: one for the player
    public function dedupeKey(): ?string
    {
        return (string) $this->userId;
    }
}
