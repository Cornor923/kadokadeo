<?php

namespace App\Http\Resources;

use App\Enums\ClanAttackStatus;
use App\Models\ClanAttack;
use App\Services\ClanWarService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin ClanAttack
 */
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
        $viewerMember = $user?->clanMember;
        $viewerClanId = $viewerMember?->clan_id;
        $isActive = $this->status === ClanAttackStatus::ACTIVE;
        $isDefenderClan = $viewerClanId !== null && $viewerClanId === $this->defender_clan_id;
        // the leader and the right hands of the attacking clan cancel any of its attacks (ClanWarService::cancelAttack)
        $isAttackerManager = $viewerClanId !== null && $viewerClanId === $this->attacker_clan_id
            && ($this->attackerClan->leader_id === $user->id || $viewerMember->role->canManage());

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
            // (not in the last hours of the period: ClanWarService::attacksClosed)
            'can_improve' => $isActive && $user?->id === $this->attacker_user_id && !app(ClanWarService::class)->attacksClosed($this->period),
            // "Je m'en occupe": only for the attacked clan
            'reserved_by' => $isDefenderClan && $this->reservedBy ? UserLightResource::make($this->reservedBy) : null,
            'reserved_at' => $isDefenderClan ? $this->reserved_at?->toIso8601String() : null,
            'reserved_by_me' => $isDefenderClan && $this->reserved_by_user_id === $user?->id,
            'can_reserve' => $isActive && $isDefenderClan,
            'can_cancel' => $isActive && ($user?->id === $this->attacker_user_id || $isAttackerManager),
        ];
    }
}
