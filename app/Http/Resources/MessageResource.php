<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Message */
// a private message in a list (its body: App\Http\Controllers\Api\MessageController::show)
class MessageResource extends JsonResource
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
            'subject' => $this->subject,
            // null: a message of the site
            'sender' => $this->sender ? UserLightResource::make($this->sender)->resolve() : null,
            'recipient' => UserLightResource::make($this->recipient)->resolve(),
            'is_read' => $this->read_at !== null,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
