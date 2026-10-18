<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

// a topic of the private forum of a clan. Unread: the player has not read its last message (last_read_message_id,
// selected with the topics by App\Http\Controllers\Api\ClanForumController).
class ClanForumTopicResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $lastRead = $this->resource->getAttribute('last_read_message_id');

        return [
            'id' => $this->id,
            'title' => $this->title,
            'is_pinned' => $this->is_pinned,
            'is_locked' => $this->is_locked,
            'replies_count' => $this->replies_count,
            'pages' => $this->pages(),
            'is_unread' => $lastRead === null || $this->last_message_id > $lastRead,
            'author' => $this->user ? UserLightResource::make($this->user) : null,
            'last_message_user' => $this->lastMessageUser ? UserLightResource::make($this->lastMessageUser) : null,
            'last_message_at' => $this->last_message_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
