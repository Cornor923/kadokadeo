<?php

namespace App\Http\Resources;

use App\Enums\ClanAttackStatus;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ClanAttackResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $user = $request->user();
        $viewerClanId = $user?->clanMember?->clan_id;
        $isActive = $this->status === ClanAttackStatus::ACTIVE;
        $isDefenderClan = $viewerClanId !== null && $viewerClanId === $this->defender_clan_id;

        return [
            'id' => $this->id,
            'status' => $this->status->value,
            'status_label' => $this->status->getLabel(),
            'game' => ['id' => $this->game->id, 'name' => $this->game->name],
            'score' => $this->score,
            'points' => $this->points,
            'expires_at' => $this->expires_at?->toIso8601String(),
            'resolved_at' => $this->resolved_at?->toIso8601String(),
            'attacker' => UserLightResource::make($this->attackerUser),
            'attacker_clan' => ['id' => $this->attackerClan->id, 'name' => $this->attackerClan->name],
            'defender_clan' => ['id' => $this->defenderClan->id, 'name' => $this->defenderClan->name],
            'defender' => $this->defenderUser ? UserLightResource::make($this->defenderUser) : null,
            'can_defend' => $isActive && $isDefenderClan,
            'can_improve' => $isActive && $user?->id === $this->attacker_user_id,
            // "Je m'en occupe": only for the attacked clan
            'reserved_by' => $isDefenderClan && $this->reservedBy ? UserLightResource::make($this->reservedBy) : null,
            'reserved_at' => $isDefenderClan ? $this->reserved_at?->toIso8601String() : null,
            'reserved_by_me' => $isDefenderClan && $this->reserved_by_user_id === $user?->id,
            'can_reserve' => $isActive && $isDefenderClan,
            'can_cancel' => $isActive && $user?->id === $this->attacker_user_id,
        ];
    }
}
