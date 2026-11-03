<?php

namespace App\Events;

use App\Http\Resources\MessageResource;
use App\Models\Message;
use App\Support\Realtime;
use App\Support\Unread;
use Illuminate\Broadcasting\Channel;

// a private message for the player: his badge, a toast, his inbox if it is open
class MessageReceived extends RealtimeEvent
{
    public function __construct(private readonly Message $message) {}

    public function broadcastOn(): Channel
    {
        return Realtime::user($this->message->recipient_id);
    }

    public function broadcastAs(): string
    {
        return 'message.received';
    }

    public function broadcastWith(): array
    {
        return [
            'message' => MessageResource::make($this->message->loadMissing('sender', 'recipient'))->resolve(),
            'unread' => Unread::counts($this->message->recipient_id),
        ];
    }
}
