<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            // only for the user themself: the name of his channel of the realtime (App\Support\Realtime::user)
            'id' => $this->when($request->user()?->is($this->resource), fn () => $this->resource->id),
            'etwin_id' => $this->etwin_id,
            'display_name' => $this->display_name,
            'kado_points' => $this->kado_points,
            'kado_games' => $this->kado_games,
            // the free games of the attacks and defenses of the clans left today
            'clan_attack_games' => $this->clan_attack_games,
            // the paid clan games of the player (App\Services\ClanGameService)
            'clan_games' => $this->clan_games,
            'theme' => $this->theme ?? 'base',
            // only for the user themself (the profiles of the other players use this resource too): the button of the
            // admin panel in the Kalendrier
            'is_admin' => $this->when($request->user()?->is($this->resource), fn () => (bool) $this->is_admin),
            // (the user themself too) App\Enums\UserPreference => bool, set on his account page
            'preferences' => $this->when($request->user()?->is($this->resource), fn () => $this->resource->preferenceValues()),
            'stars' => $this->whenLoaded('stars', fn () => UserStarResource::make($this->stars->first())),
            'achievement_progress' => $this->whenLoaded('achievementProgress', fn () => UserAchievementProgressResource::collection($this->achievementProgress)),
        ];
    }
}
