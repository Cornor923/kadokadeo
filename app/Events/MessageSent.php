<?php

namespace App\Events;

use App\Http\Resources\MessageResource;
use App\Models\Message;
use App\Support\Realtime;
use Illuminate\Broadcasting\Channel;

// a private message sent by the player: his box « Envoyés » open in another tab
class MessageSent extends RealtimeEvent
{
    public function __construct(private readonly Message $message) {}

    public function broadcastOn(): Channel
    {
        return Realtime::user($this->message->sender_id);
    }

    public function broadcastAs(): string
    {
        return 'message.sent';
    }

    public function broadcastWith(): array
    {
        return ['message' => MessageResource::make($this->message->loadMissing('sender', 'recipient'))->resolve()];
    }
}
