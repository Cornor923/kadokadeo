<?php

namespace App\Support;

use App\Models\Message;
use App\Models\User;
use App\Models\UserNotification;

// what the player has not read yet: the badge of the mail of the Kalendrier
class Unread
{
    /** @return array{messages: int, notifications: int} */
    public static function counts(User|int $user): array
    {
        $id = $user instanceof User ? $user->id : $user;

        return [
            'messages' => Message::query()->where('recipient_id', $id)->whereNull('recipient_deleted_at')->whereNull('read_at')->count(),
            'notifications' => UserNotification::query()->where('user_id', $id)->unread()->count(),
        ];
    }
}
