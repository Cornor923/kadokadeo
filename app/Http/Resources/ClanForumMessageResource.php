<?php

namespace App\Http\Resources;

use App\Enums\ClanRole;
use App\Services\ClanForumService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

// a message of the private forum of a clan, for the player reading it (request attributes set by
// App\Http\Controllers\Api\ClanForumController: "forum_moderator", "forum_roles"). A deleted message keeps its content
// for the moderators only, who can restore it.
class ClanForumMessageResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $isModerator = (bool) $request->attributes->get('forum_moderator');
        /** @var ClanRole|null $role */
        $role = $request->attributes->get('forum_roles', [])[$this->user_id] ?? null;
        $isDeleted = $this->trashed();

        return [
            'id' => $this->id,
            'author' => $this->user ? UserLightResource::make($this->user) : null,
            // his role in the clan today: none when he left it
            'author_role' => $role?->value,
            'author_role_label' => $role?->getLabel(),
            'content' => $isDeleted && !$isModerator ? null : $this->content,
            'created_at' => $this->created_at?->toIso8601String(),
            'edited_at' => $this->edited_at?->toIso8601String(),
            'is_deleted' => $isDeleted,
            'can_edit' => app(ClanForumService::class)->canEdit($request->user(), $this->resource, $isModerator),
        ];
    }
}
