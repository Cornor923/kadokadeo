<?php

namespace App\Services;

use App\Models\Message;
use App\Models\User;

// the private messages: between players, and the messages of the site (the answer to an application to a clan...). Their
// body is written in Marktwin, rendered by the client (resources/js/composables/useMarktwin.js), as the clan forums.
class MessageService
{
    public function send(User $sender, User $recipient, string $subject, string $body): Message
    {
        return Message::query()->create([
            'sender_id' => $sender->id,
            'recipient_id' => $recipient->id,
            'subject' => $subject,
            'body' => $body,
        ]);
    }

    // signed "KadoKado"
    public function system(User|int $recipient, string $subject, string $body): Message
    {
        return Message::query()->create([
            'sender_id' => null,
            'recipient_id' => $recipient instanceof User ? $recipient->id : $recipient,
            'subject' => $subject,
            'body' => $body,
        ]);
    }

    // a message of the site to every player not banned (sent from the admin panel): the number of messages sent
    public function systemToAll(string $subject, string $body): int
    {
        $sent = 0;
        User::query()->whereNull('banned_at')->select('id')->chunkById(500, function ($users) use ($subject, $body, &$sent) {
            $now = now();
            Message::query()->insert($users->map(fn (User $user) => [
                'sender_id' => null,
                'recipient_id' => $user->id,
                'subject' => $subject,
                'body' => $body,
                'created_at' => $now,
                'updated_at' => $now,
            ])->all());
            $sent += $users->count();
        });

        return $sent;
    }

    public function unreadCount(User $user): int
    {
        return Message::query()->inboxOf($user)->whereNull('read_at')->count();
    }

    // each side deletes it from its own box; gone once both did
    public function delete(User $user, Message $message): void
    {
        if ($message->recipient_id === $user->id) {
            $message->recipient_deleted_at = now();
        }
        if ($message->sender_id === $user->id) {
            $message->sender_deleted_at = now();
        }
        $message->save();

        if ($message->recipient_deleted_at && ($message->sender_id === null || $message->sender_deleted_at)) {
            $message->delete();
        }
    }
}
