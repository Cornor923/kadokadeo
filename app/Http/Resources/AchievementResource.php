<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AchievementResource extends JsonResource
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
            'game' => $this->whenLoaded('game', fn () => $this->game->only('id', 'name')),
            'levels' => $this->whenLoaded('levels', fn () => AchievementLevelResource::collection($this->levels)),
        ];
    }
}
