<?php

namespace App\Services;

use App\Enums\ClanRole;
use App\Exceptions\ClanException;
use App\Models\Clan;
use App\Models\ClanForumMessage;
use App\Models\ClanForumRead;
use App\Models\ClanForumTopic;
use App\Models\User;
use Illuminate\Support\Facades\DB;

// the private forum of a clan: its members read it and write in it, its leader and its right hands moderate it (pin and
// lock the topics, delete and restore the messages, delete the topics). The messages are written in Marktwin, rendered
// by the client (resources/js/marktwin): the server keeps the text as it was written.
class ClanForumService
{
    public function __construct(private readonly ClanService $clanService) {}

    public function canModerate(User $user, Clan $clan): bool
    {
        return (bool) $this->clanService->roleOf($user, $clan)?->canManage();
    }

    public function assertModerator(User $user, Clan $clan): void
    {
        $this->clanService->assertManager($user, $clan);
    }

    // the roles in the clan of its members (by user id): the leader (clans.leader_id) and the right hands
    public function rolesOf(Clan $clan): array
    {
        $roles = $clan->members()->pluck('role', 'user_id')->all();
        if ($clan->leader_id) {
            $roles[$clan->leader_id] = ClanRole::LEADER;
        }

        return $roles;
    }

    public function createTopic(User $user, Clan $clan, string $title, string $content): ClanForumTopic
    {
        $this->clanService->assertMember($user, $clan);

        return DB::transaction(function () use ($user, $clan, $title, $content) {
            $topic = $clan->forumTopics()->create(['user_id' => $user->id, 'title' => $title]);
            $message = $topic->messages()->create(['user_id' => $user->id, 'content' => $content]);
            $topic->update([
                'last_message_id' => $message->id,
                'last_message_user_id' => $user->id,
                'last_message_at' => $message->created_at,
            ]);
            $this->markRead($user, $topic, $message->id);

            return $topic;
        });
    }

    public function reply(User $user, ClanForumTopic $topic, string $content): ClanForumMessage
    {
        $this->clanService->assertMember($user, $topic->clan);
        if ($topic->is_locked && !$this->canModerate($user, $topic->clan)) {
            throw new ClanException('Ce sujet est verrouillé.');
        }

        return DB::transaction(function () use ($user, $topic, $content) {
            $message = $topic->messages()->create(['user_id' => $user->id, 'content' => $content]);
            $topic->increment('replies_count', 1, [
                'last_message_id' => $message->id,
                'last_message_user_id' => $user->id,
                'last_message_at' => $message->created_at,
            ]);
            $this->markRead($user, $topic, $message->id);

            return $message;
        });
    }

    // the author edits his message while the topic is open, a moderator any message (not the deleted ones: restore them
    // first)
    public function canEdit(User $user, ClanForumMessage $message, bool $isModerator): bool
    {
        if ($message->trashed()) {
            return false;
        }

        return $isModerator || ($message->user_id === $user->id && !$message->topic->is_locked);
    }

    public function editMessage(User $user, ClanForumMessage $message, string $content): ClanForumMessage
    {
        $clan = $message->topic->clan;
        $this->clanService->assertMember($user, $clan);
        if (!$this->canEdit($user, $message, $this->canModerate($user, $clan))) {
            throw new ClanException('Vous ne pouvez pas modifier ce message.');
        }
        $message->update(['content' => $content, 'edited_at' => now(), 'edited_by' => $user->id]);

        return $message;
    }

    public function deleteMessage(User $user, ClanForumMessage $message): void
    {
        $this->assertModerator($user, $message->topic->clan);
        if ($message->trashed()) {
            return;
        }
        // the soft delete only writes deleted_at
        DB::transaction(function () use ($user, $message) {
            $message->update(['deleted_by' => $user->id]);
            $message->delete();
        });
    }

    public function restoreMessage(User $user, ClanForumMessage $message): void
    {
        $this->assertModerator($user, $message->topic->clan);
        if (!$message->trashed()) {
            return;
        }
        $message->deleted_by = null;
        $message->restore();
    }

    // the title: its author or a moderator; pinned and locked: a moderator
    public function updateTopic(User $user, ClanForumTopic $topic, array $changes): ClanForumTopic
    {
        $clan = $topic->clan;
        $this->clanService->assertMember($user, $clan);
        $isModerator = $this->canModerate($user, $clan);
        if (array_key_exists('title', $changes) && !$isModerator && $topic->user_id !== $user->id) {
            throw new ClanException('Seul l\'auteur du sujet peut changer son titre.');
        }
        if ((array_key_exists('is_pinned', $changes) || array_key_exists('is_locked', $changes)) && !$isModerator) {
            throw new ClanException('Seuls le chef de clan et ses bras droits peuvent faire ça.');
        }
        $topic->update($changes);

        return $topic;
    }

    public function deleteTopic(User $user, ClanForumTopic $topic): void
    {
        $this->assertModerator($user, $topic->clan);
        $topic->delete();
    }

    // the messages read up to $messageId (a page shown): the last read message only moves forward
    public function markRead(User $user, ClanForumTopic $topic, int $messageId): void
    {
        $read = ClanForumRead::query()->firstOrNew(['user_id' => $user->id, 'topic_id' => $topic->id]);
        if ($read->exists && $read->last_read_message_id >= $messageId) {
            return;
        }
        $read->last_read_message_id = $messageId;
        $read->save();
    }
}
