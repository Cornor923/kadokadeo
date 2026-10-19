<?php

namespace App\Http\Resources;

use App\Services\RunCommentService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

// a comment of a replay for the player reading it (request attribute "run_comment_likes", set by
// App\Http\Controllers\Api\RunCommentController: the ids of the comments he likes, as keys). A deleted comment shown
// for its answers has no text.
class RunCommentResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $user = $request->user();
        $service = app(RunCommentService::class);
        $isDeleted = $this->trashed();

        return [
            'id' => $this->id,
            'parent_id' => $this->parent_id,
            'frame' => $this->frame,
            'author' => $this->user ? UserLightResource::make($this->user) : null,
            'content' => $isDeleted ? null : $this->content,
            'likes_count' => $this->likes_count,
            'liked' => isset($request->attributes->get('run_comment_likes', [])[$this->id]),
            'created_at' => $this->created_at?->toIso8601String(),
            'edited_at' => $this->edited_at?->toIso8601String(),
            'is_deleted' => $isDeleted,
            'is_own' => $user !== null && $this->user_id === $user->id,
            'can_edit' => $service->canEdit($user, $this->resource),
            'can_delete' => $service->canDelete($user, $this->resource),
        ];
    }
}
