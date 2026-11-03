<?php

namespace App\Http\Resources;

use App\Models\UserNotification;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Str;

/** @mixin UserNotification */
// a notification of the player (App\Services\NotificationService): the front writes its text from its type
class UserNotificationResource extends JsonResource
{
    // what it shows
    public const RELATIONS = ['actor:id,etwin_id,display_name', 'run:id,game_id', 'run.game:id,name', 'comment:id,run_id,parent_id,frame,content', 'clan:id,name'];

    public static function loadFor(UserNotification $notification): UserNotification
    {
        return $notification->loadMissing(self::RELATIONS);
    }

    public static function eagerLoad(Builder $query): Builder
    {
        return $query->with(self::RELATIONS);
    }

    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'type' => $this->type->value,
            'count' => $this->count,
            'read' => $this->read_at !== null,
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
            'actor' => $this->actor ? UserLightResource::make($this->actor)->resolve() : null,
            'run' => $this->run ? [
                'id' => $this->run->id,
                'game' => $this->run->game ? ['id' => $this->run->game->id, 'name' => $this->run->game->name] : null,
            ] : null,
            'comment' => $this->comment ? [
                'id' => $this->comment->id,
                'parent_id' => $this->comment->parent_id,
                'frame' => $this->comment->frame,
                'excerpt' => Str::limit($this->comment->content, 80),
            ] : null,
            'clan' => $this->clan ? ['id' => $this->clan->id, 'name' => $this->clan->name] : null,
        ];
    }
}
