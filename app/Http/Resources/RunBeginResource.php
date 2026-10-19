<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RunBeginResource extends JsonResource
{
    // a clan run: its goal (App\Services\ClanRunService::goal)
    private ?array $clan = null;

    public function withClan(?array $clan): static
    {
        $this->clan = $clan;

        return $this;
    }

    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'run_id' => $this->id,
            'server_time' => $this->created_at->timestamp,
            'contract_score' => $this->contract_score,
            'contract_points' => $this->contract_points,
            'seed' => $this->seed,
            // the daily game: the same seed (and pieces) for every player, the draws are not stirred (kado.Seed.stir)
            'shared_seed' => $this->daily_game_id !== null,
            'clan' => $this->clan,
        ];
    }
}
