<?php

namespace App\Events;

use App\Http\Resources\PeriodResource;
use App\Models\Period;
use App\Support\Realtime;
use Illuminate\Broadcasting\Channel;

// a new period (kado:prepare-new-period): the leagues, the scores, the tournament of the clans start again
class PeriodStarted extends RealtimeEvent
{
    public function broadcastOn(): Channel
    {
        return Realtime::site();
    }

    public function broadcastAs(): string
    {
        return 'period.started';
    }

    // the same for every player: in the event rather than every page asking it at once (read when sent)
    public function broadcastWith(): array
    {
        $period = Period::current()->first();

        return ['period' => $period ? PeriodResource::make($period)->resolve() : null];
    }

    // once by request
    public function dedupeKey(): ?string
    {
        return '';
    }
}
