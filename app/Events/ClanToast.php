<?php

namespace App\Events;

use App\Models\Game;
use App\Models\User;
use App\Support\Realtime;
use Illuminate\Broadcasting\Channel;

// a feat of a member, shown to the other members connected for a few seconds (not kept): a defense won, a step of the
// mission done, a new mission available
class ClanToast extends RealtimeEvent
{
    public const DEFENSE_REPELLED = 'defense_repelled';

    public const STEP_COMPLETED = 'step_completed';

    public const MISSION_AVAILABLE = 'mission_available';

    private function __construct(
        private readonly int $clanId,
        private readonly string $kind,
        private readonly ?User $player = null,
        private readonly ?Game $game = null,
        private readonly ?int $score = null,
    ) {}

    public static function defenseRepelled(int $clanId, User $player, Game $game, int $score): self
    {
        return new self($clanId, self::DEFENSE_REPELLED, $player, $game, $score);
    }

    public static function stepCompleted(int $clanId, User $player, Game $game, int $score): self
    {
        return new self($clanId, self::STEP_COMPLETED, $player, $game, $score);
    }

    public static function missionAvailable(int $clanId): self
    {
        return new self($clanId, self::MISSION_AVAILABLE);
    }

    public function broadcastOn(): Channel
    {
        return Realtime::clan($this->clanId);
    }

    public function broadcastAs(): string
    {
        return 'clan.toast';
    }

    public function broadcastWith(): array
    {
        return [
            'kind' => $this->kind,
            'clan_id' => $this->clanId,
            // (the player himself does not see it)
            'player' => $this->player ? ['etwin_id' => $this->player->etwin_id, 'display_name' => $this->player->display_name] : null,
            'game' => $this->game ? ['id' => $this->game->id, 'name' => $this->game->name] : null,
            'score' => $this->score,
        ];
    }
}
