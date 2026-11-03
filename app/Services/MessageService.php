<?php

namespace App\Services;

use App\Events\MessageReceived;
use App\Events\MessageSent;
use App\Events\SystemMessageSent;
use App\Events\UnreadCountsChanged;
use App\Models\Message;
use App\Models\User;
use App\Support\Realtime;

// the private messages: between players, and the messages of the site (the answer to an application to a clan...). Their
// body is written in Marktwin, rendered by the client (resources/js/composables/useMarktwin.js), as the clan forums. The
// players are told at once (App\Events\MessageReceived), their other tabs follow what they read and delete.
class MessageService
{
    public function send(User $sender, User $recipient, string $subject, string $body): Message
    {
        $message = Message::query()->create([
            'sender_id' => $sender->id,
            'recipient_id' => $recipient->id,
            'subject' => $subject,
            'body' => $body,
        ]);
        Realtime::send(new MessageReceived($message));
        Realtime::send(new MessageSent($message));

        return $message;
    }

    // signed "KadoKado"
    public function system(User|int $recipient, string $subject, string $body): Message
    {
        $message = Message::query()->create([
            'sender_id' => null,
            'recipient_id' => $recipient instanceof User ? $recipient->id : $recipient,
            'subject' => $subject,
            'body' => $body,
        ]);
        Realtime::send(new MessageReceived($message));

        return $message;
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
        Realtime::send(new SystemMessageSent());

        return $sent;
    }

    public function unreadCount(User $user): int
    {
        return Message::query()->inboxOf($user)->whereNull('read_at')->count();
    }

    // read by its recipient (the badge of his other tabs)
    public function markRead(Message $message): void
    {
        if ($message->read_at === null) {
            $message->update(['read_at' => now()]);
            Realtime::send(new UnreadCountsChanged($message->recipient_id));
        }
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
        if ($message->recipient_id === $user->id && $message->read_at === null) {
            Realtime::send(new UnreadCountsChanged($user));
        }
    }
}
