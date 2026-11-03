<?php

namespace App\Events;

use App\Support\Realtime;
use Illuminate\Broadcasting\Channel;

// something of the clan changed: the pages of its members open on it reload these parts
class ClanUpdated extends RealtimeEvent
{
    // its presentation (name, description, recruitment)
    public const CLAN = 'clan';

    // the members, their roles and seats, the applications
    public const MEMBERS = 'members';

    // the war: attacks received and sent, defenses, scores
    public const STATUS = 'status';

    public const MISSIONS = 'missions';

    public const HISTORY = 'history';

    /** @param  list<string>  $parts */
    public function __construct(private readonly int $clanId, private readonly array $parts) {}

    // the same change seen by several clans (the attacker and the defender)
    /**
     * @param  iterable<int|null>  $clanIds
     * @param  list<string>  $parts
     */
    public static function send(iterable $clanIds, array $parts): void
    {
        foreach (array_unique(array_filter([...$clanIds])) as $clanId) {
            Realtime::send(new self($clanId, $parts));
        }
    }

    public function broadcastOn(): Channel
    {
        return Realtime::clan($this->clanId);
    }

    public function broadcastAs(): string
    {
        return 'clan.updated';
    }

    public function broadcastWith(): array
    {
        return ['parts' => array_values(array_unique($this->parts))];
    }

    // one for the clan, with every part that changed
    public function dedupeKey(): ?string
    {
        return (string) $this->clanId;
    }

    public function mergedWith(RealtimeEvent $earlier): RealtimeEvent
    {
        return $earlier instanceof self ? new self($this->clanId, [...$earlier->parts, ...$this->parts]) : $this;
    }
}
