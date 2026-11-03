<?php

namespace App\Services;

use App\Enums\ClanRole;
use App\Enums\NotificationType;
use App\Enums\UserPreference;
use App\Events\NotificationReceived;
use App\Events\UnreadCountsChanged;
use App\Models\ClanApplication;
use App\Models\ClanMember;
use App\Models\RunComment;
use App\Models\RunCommentLike;
use App\Models\User;
use App\Models\UserNotification;
use App\Support\Realtime;
use Illuminate\Database\Eloquent\Builder;

// The notifications of the players, next to their private messages (the tab « Notifications »), sent at once by the
// realtime (App\Events\NotificationReceived): the comments on their replays and the answers to their comments (each one
// a preference of the player, App\Enums\UserPreference), the likes of a comment in one notification (it comes back on
// top, unread, at each like), the applications to their clan (leader and right hands) and their own one answered. Never
// for what the player did himself. Deleted by the player, or two months after their last change (UserNotification).
class NotificationService
{
    // a comment on a replay: the author of the comment it answers, the player of the run (once, the answer first)
    public function commentCreated(RunComment $comment): void
    {
        $comment->loadMissing('run.user', 'parent.user');
        $notified = null;

        $parentAuthor = $comment->parent?->user;
        if ($parentAuthor && $parentAuthor->id !== $comment->user_id && $parentAuthor->prefers(UserPreference::NOTIFY_COMMENT_REPLIES)) {
            $this->notify($parentAuthor->id, NotificationType::COMMENT_REPLY, $comment->user_id, $this->aboutComment($comment));
            $notified = $parentAuthor->id;
        }

        $player = $comment->run?->user;
        if ($player && $player->id !== $comment->user_id && $player->id !== $notified && $player->prefers(UserPreference::NOTIFY_RUN_COMMENTS)) {
            $this->notify($player->id, NotificationType::RUN_COMMENT, $comment->user_id, $this->aboutComment($comment));
        }
    }

    // one notification for all the likes of the comment: the last one who liked it, how many like it now
    public function commentLiked(RunComment $comment, User $liker): void
    {
        $author = $comment->user_id ? User::query()->find($comment->user_id) : null;
        if (!$author || $author->id === $liker->id || !$author->prefers(UserPreference::NOTIFY_COMMENT_LIKES)) {
            return;
        }

        $now = now();
        // (two likes at once: one row, the unique key)
        UserNotification::query()->upsert([[
            'user_id' => $author->id,
            'group_key' => $this->likesKey($comment),
            'type' => NotificationType::COMMENT_LIKES->value,
            'actor_id' => $liker->id,
            ...$this->aboutComment($comment),
            'count' => $this->likesCount($comment),
            'read_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]], ['user_id', 'group_key'], ['actor_id', 'count', 'read_at', 'updated_at']);

        $notification = UserNotification::query()->where('user_id', $author->id)->where('group_key', $this->likesKey($comment))->first();
        if ($notification) {
            Realtime::send(new NotificationReceived($notification));
        }
    }

    // a like taken back: counted again, quietly (not on top, not unread again); gone with the last like
    public function commentUnliked(RunComment $comment, User $unliker): void
    {
        $notification = UserNotification::query()->where('user_id', $comment->user_id)->where('group_key', $this->likesKey($comment))->first();
        if (!$notification) {
            return;
        }

        $count = $this->likesCount($comment);
        if ($count <= 0) {
            $notification->delete();
            if ($notification->read_at === null) {
                Realtime::send(new UnreadCountsChanged($notification->user_id));
            }

            return;
        }

        $notification->count = $count;
        if ($notification->actor_id === $unliker->id) {
            $notification->actor_id = RunCommentLike::query()->where('comment_id', $comment->id)->orderByDesc('created_at')->value('user_id');
        }
        $notification->timestamps = false;
        $notification->save();
    }

    // the comment deleted: what it notified goes away (its likes, its answer, the comment itself); its answers too when
    // they go with it (deleted for good)
    public function commentDeleted(RunComment $comment, bool $withReplies = false): void
    {
        $ids = [$comment->id, ...($withReplies ? RunComment::withTrashed()->where('parent_id', $comment->id)->pluck('id')->all() : [])];
        $this->remove(UserNotification::query()->whereIn('comment_id', $ids));
    }

    // for the leader and the right hands of the clan (who can answer it)
    public function clanApplied(ClanApplication $application): void
    {
        $clan = $application->clan;
        $managers = ClanMember::query()
            ->where('clan_id', $clan->id)
            ->where(fn ($q) => $q->where('user_id', $clan->leader_id)->orWhere('role', ClanRole::RIGHT_HAND->value))
            ->pluck('user_id');

        foreach ($managers as $managerId) {
            if ($managerId === $application->user_id) {
                continue;
            }
            $this->notify($managerId, NotificationType::CLAN_APPLICATION, $application->user_id, [
                'clan_id' => $clan->id,
                'clan_application_id' => $application->id,
            ], "clan-app:{$application->id}");
        }
    }

    // answered (or withdrawn, or the clan disbanded): nothing left to do for the managers
    public function clanApplicationClosed(ClanApplication $application): void
    {
        $this->remove(UserNotification::query()->where('clan_application_id', $application->id));
    }

    public function clanAccepted(ClanApplication $application, User $manager): void
    {
        $this->notify($application->user_id, NotificationType::CLAN_ACCEPTED, $manager->id, ['clan_id' => $application->clan_id]);
    }

    public function clanRefused(ClanApplication $application, User $manager): void
    {
        $this->notify($application->user_id, NotificationType::CLAN_REFUSED, $manager->id, ['clan_id' => $application->clan_id]);
    }

    // the notifications the player sees (not the ones of a comment deleted meanwhile)
    public function visibleOf(User $user): Builder
    {
        return UserNotification::query()
            ->where('user_id', $user->id)
            ->where(fn ($q) => $q->whereNull('comment_id')->orWhereHas('comment'));
    }

    public function markAllRead(User $user): void
    {
        if (UserNotification::query()->where('user_id', $user->id)->unread()->update(['read_at' => now()]) > 0) {
            Realtime::send(new UnreadCountsChanged($user));
        }
    }

    public function delete(UserNotification $notification): void
    {
        $notification->delete();
        Realtime::send(new UnreadCountsChanged($notification->user_id));
    }

    public function deleteAll(User $user): void
    {
        UserNotification::query()->where('user_id', $user->id)->delete();
        Realtime::send(new UnreadCountsChanged($user));
    }

    private function notify(int $userId, NotificationType $type, ?int $actorId, array $about, ?string $groupKey = null): UserNotification
    {
        $notification = UserNotification::query()->create([
            'user_id' => $userId,
            'type' => $type,
            'actor_id' => $actorId,
            'group_key' => $groupKey,
            ...$about,
        ]);
        Realtime::send(new NotificationReceived($notification));

        return $notification;
    }

    // the notifications of the query deleted, the badge of their players changed
    private function remove(Builder $query): void
    {
        $unreadOf = (clone $query)->whereNull('read_at')->distinct()->pluck('user_id');
        $query->delete();
        foreach ($unreadOf as $userId) {
            Realtime::send(new UnreadCountsChanged($userId));
        }
    }

    private function aboutComment(RunComment $comment): array
    {
        return ['run_id' => $comment->run_id, 'comment_id' => $comment->id];
    }

    private function likesKey(RunComment $comment): string
    {
        return "likes:{$comment->id}";
    }

    private function likesCount(RunComment $comment): int
    {
        return (int) RunComment::withTrashed()->whereKey($comment->id)->value('likes_count');
    }
}
