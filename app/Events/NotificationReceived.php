<?php

namespace App\Events;

use App\Http\Resources\UserNotificationResource;
use App\Models\UserNotification;
use App\Support\Realtime;
use App\Support\Unread;
use Illuminate\Broadcasting\Channel;

// a notification new, or one grouping more (likes), for the player: his badge, a toast, the tab « Notifications »
class NotificationReceived extends RealtimeEvent
{
    public function __construct(private readonly UserNotification $notification) {}

    public function broadcastOn(): Channel
    {
        return Realtime::user($this->notification->user_id);
    }

    public function broadcastAs(): string
    {
        return 'notification.received';
    }

    public function broadcastWith(): array
    {
        return [
            'notification' => UserNotificationResource::make(UserNotificationResource::loadFor($this->notification))->resolve(),
            'unread' => Unread::counts($this->notification->user_id),
        ];
    }
}
