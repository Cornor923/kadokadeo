<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class GameResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $user = $request->user();

        return [
            'id' => $this->id,
            'category_id' => $this->category_id,
            'name' => $this->name,
            'is_arkadeo' => $this->is_arkadeo,
            'pascal_name' => $this->pascal_name,
            'description' => $this->description,
            'image_path' => $this->image_path,
            'stars' => $this->stars,
            'score_rankv1' => $this->score_rankv1,
            'gamedata' => $this->gamedata,
            'controls' => GameControlResource::collection($this->whenLoaded('controls')),
            'is_favorite' => $this->when(
                $user?->relationLoaded('favorite'),
                fn () => $user->favorite->contains('game_id', $this->id),
            ),
            'user_star' => $this->whenLoaded('periodStars', function () {
                $periodStar = $this->periodStars->first();

                return $periodStar ? $periodStar->star : null;
            }),
        ];
    }
}
