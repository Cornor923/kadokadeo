<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

// a clan of a ranking (App\Services\ClanService::rankingQuery), with its scores of the period
class ClanListResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'is_recruiting' => $this->is_recruiting,
            'members_count' => $this->members_count ?? null,
            'rank' => $this->rank ?? null,
            'war_score' => (int) ($this->war_score ?? 0),
            'mission_score' => (int) ($this->mission_score ?? 0),
            'attacks_won' => (int) ($this->attacks_won ?? 0),
            'defenses_won' => (int) ($this->defenses_won ?? 0),
            'missions_completed' => (int) ($this->missions_completed ?? 0),
            // the missions ranking: the mission in progress, {number, steps, steps_done}
            'mission' => $this->mission ?? null,
        ];
    }
}
