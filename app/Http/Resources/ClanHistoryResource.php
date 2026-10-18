<?php

namespace App\Http\Resources;

use App\Enums\ClanAttackStatus;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

// a finished attack in the "Historique" of a clan (the clan of the route), from its side: an attack (A) when the clan
// launched it, a defense (D) when it received it. The player and the score are the ones of the clan: the attacker of an
// attack, the defender of a repelled attack (none when it was not repelled, the score is then the one of the attack).
// The points: won by an attack, lost by an attack not repelled, and for a repelled attack the points of the defender in
// the ranking of his clan.
class ClanHistoryResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $isAttack = $this->attacker_clan_id === $request->route('clan')->id;
        $won = $this->status === ClanAttackStatus::WON;
        $other = $isAttack ? $this->defenderClan : $this->attackerClan;
        $player = $isAttack ? $this->attackerUser : $this->defenderUser;

        return [
            'id' => $this->id,
            'date' => $this->resolved_at?->toIso8601String(),
            'type' => $isAttack ? 'attack' : 'defense',
            'player' => $player ? UserLightResource::make($player) : null,
            'clan' => ['id' => $other->id, 'name' => $other->name],
            'game' => ['id' => $this->game->id, 'name' => $this->game->name],
            'score' => $isAttack || $won ? $this->score : $this->defenseRun?->score,
            'status' => $this->status->value,
            'status_label' => match (true) {
                $isAttack => $this->status->getLabel(),
                $won => 'Non repoussée',
                default => 'Repoussée',
            },
            // the other player: the defender who repelled an attack, the attacker of an attack not repelled
            'other_player' => match (true) {
                $isAttack && !$won && $this->defenderUser => UserLightResource::make($this->defenderUser),
                !$isAttack && $won => UserLightResource::make($this->attackerUser),
                default => null,
            },
            // the score of the defender who repelled an attack of the clan
            'other_score' => $isAttack && !$won ? $this->defenseRun?->score : null,
            'points' => match (true) {
                $isAttack && $won => $this->points,
                $isAttack => 0,
                $won => -$this->points,
                default => $this->points,
            },
        ];
    }
}
