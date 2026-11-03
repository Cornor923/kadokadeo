<?php

namespace App\Events;

use App\Support\Realtime;
use Illuminate\Broadcasting\Channel;

// the leaderboard of a game changed (a run in its top 10, a record, a run taken out): the pages showing it reload it
class GameScoresChanged extends RealtimeEvent
{
    // $leagueId null: every league of the period
    public function __construct(
        private readonly int $gameId,
        private readonly ?int $periodId,
        private readonly ?int $leagueId,
        private readonly bool $worldBest = false,
    ) {}

    public function broadcastOn(): Channel
    {
        return Realtime::game($this->gameId);
    }

    public function broadcastAs(): string
    {
        return 'scores.changed';
    }

    public function broadcastWith(): array
    {
        return [
            'game_id' => $this->gameId,
            'period_id' => $this->periodId,
            'league_id' => $this->leagueId,
            'world_best' => $this->worldBest,
        ];
    }

    // one by leaderboard of the period: its league, or every league when two changed
    public function dedupeKey(): ?string
    {
        return "{$this->gameId}:{$this->periodId}";
    }

    public function mergedWith(RealtimeEvent $earlier): RealtimeEvent
    {
        return $earlier instanceof self ? new self(
            $this->gameId,
            $this->periodId,
            $earlier->leagueId === $this->leagueId ? $this->leagueId : null,
            $earlier->worldBest || $this->worldBest,
        ) : $this;
    }
}
