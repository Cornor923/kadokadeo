<?php

namespace App\Services;

use App\Events\RunCommentsChanged;
use App\Exceptions\RunCommentException;
use App\Models\Run;
use App\Models\RunComment;
use App\Models\RunCommentLike;
use App\Models\User;
use App\Settings\ReplaySettings;
use App\Support\Realtime;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

// The comments of a replay, SoundCloud style: each one at a frame of the replay (a mark in the progress bar of the
// replay, shown over the game when the replay reaches it), the answers (one level) at the frame of the comment they
// answer. Plain text on one line. Their author edits and deletes them, the player of the run and the admins delete them
// (the admins restore them). The player of the run and the author of the comment answered are notified, the author of
// a comment of its likes (App\Services\NotificationService); the pages of the replay open follow its comments
// (App\Events\RunCommentsChanged). Counters kept on the rows (runs.comments_count, run_comments.replies_count / likes_count):
// the replay page reads them without counting. Limits: App\Settings\ReplaySettings.
class RunCommentService
{
    public function __construct(
        private readonly ReplaySettings $settings,
        private readonly ReportService $reportService,
        private readonly NotificationService $notifications,
    ) {}

    // the comments of the replay page, in the order of the replay: a deleted comment is still there (without its text)
    // while it has answers
    public function forReplay(Run $run): Collection
    {
        $comments = RunComment::withTrashed()
            ->where('run_id', $run->id)
            ->with('user:id,etwin_id,display_name')
            ->orderBy('frame')
            ->orderBy('id')
            ->get();

        return $comments
            ->filter(fn (RunComment $comment) => !$comment->trashed() || ($comment->parent_id === null && $comment->replies_count > 0))
            ->each(fn (RunComment $comment) => $comment->setRelation('run', $run))
            ->values();
    }

    // the ids of the comments of the replay liked by $user
    public function likedBy(User $user, Run $run): array
    {
        return RunCommentLike::query()
            ->where('user_id', $user->id)
            ->whereIn('comment_id', RunComment::query()->select('id')->where('run_id', $run->id))
            ->pluck('comment_id')
            ->all();
    }

    public function canComment(): bool
    {
        return $this->settings->comments_enabled;
    }

    // the longest text, the column holding 1000 characters
    public function maxLength(): int
    {
        return max(1, min(1000, $this->settings->comment_max_length));
    }

    // $frame: the frame of the replay the comment is at (an answer is at the frame of its comment)
    public function create(User $user, Run $run, int $frame, string $content, ?RunComment $parent = null): RunComment
    {
        if (!$this->canComment()) {
            throw new RunCommentException('Les commentaires sont désactivés pour le moment.');
        }
        $content = $this->clean($content);
        if ($parent) {
            if ($parent->run_id !== $run->id || $parent->trashed()) {
                throw new RunCommentException('Ce commentaire n\'existe plus.');
            }
            if ($parent->parent_id !== null) {
                throw new RunCommentException('On ne peut pas répondre à une réponse.');
            }
            $frame = $parent->frame;
        }
        $frame = max(0, $run->replay_frames > 0 ? min($frame, $run->replay_frames) : $frame);

        $comment = DB::transaction(function () use ($user, $run, $frame, $content, $parent) {
            // the run locked until the comment is counted: comments sent at once can't all pass the limits
            $run->comments_count = (int) Run::withTrashed()->whereKey($run->id)->lockForUpdate()->value('comments_count');
            if ($run->comments_count >= $this->settings->comments_max_per_run) {
                throw new RunCommentException('Ce replay a atteint le nombre maximum de commentaires.');
            }
            // the deleted ones too: deleting does not give the right to write again
            $written = RunComment::withTrashed()->where('user_id', $user->id)->where('run_id', $run->id)->count();
            if ($written >= $this->settings->comments_max_per_user_per_run) {
                throw new RunCommentException('Vous avez déjà beaucoup commenté ce replay.');
            }

            $comment = RunComment::create([
                'run_id' => $run->id,
                'user_id' => $user->id,
                'parent_id' => $parent?->id,
                'frame' => $frame,
                'content' => $content,
            ]);
            $this->count($run, 1);
            if ($parent) {
                RunComment::withTrashed()->whereKey($parent->id)->toBase()->increment('replies_count');
            }

            return $comment->setRelation('run', $run)->setRelation('user', $user);
        });
        $this->notifications->commentCreated($comment);
        Realtime::send(RunCommentsChanged::comment($comment, $user));

        return $comment;
    }

    public function canEdit(?User $user, RunComment $comment): bool
    {
        return $user && !$comment->trashed() && $comment->user_id === $user->id;
    }

    // its author, the player of the run (his replay), an admin
    public function canDelete(?User $user, RunComment $comment): bool
    {
        if (!$user || $comment->trashed()) {
            return false;
        }

        return $user->is_admin || $comment->user_id === $user->id || $comment->run?->user_id === $user->id;
    }

    // the text only: the comment stays at its frame
    public function update(User $user, RunComment $comment, string $content): RunComment
    {
        if (!$this->canEdit($user, $comment) && !$user->is_admin) {
            throw new RunCommentException('Vous ne pouvez pas modifier ce commentaire.');
        }
        $comment->update(['content' => $this->clean($content), 'edited_at' => now()]);
        Realtime::send(RunCommentsChanged::comment($comment, $user));

        return $comment;
    }

    // the open reports of the comment are closed (the content is gone)
    public function delete(User $user, RunComment $comment): void
    {
        if ($comment->trashed()) {
            return;
        }
        if (!$this->canDelete($user, $comment)) {
            throw new RunCommentException('Vous ne pouvez pas supprimer ce commentaire.');
        }
        DB::transaction(function () use ($user, $comment) {
            // only if it is still there: of two deletes sent at once, the second one deletes nothing and counts nothing
            $now = $comment->freshTimestamp();
            if (RunComment::query()->whereKey($comment->id)->update(['deleted_at' => $now, 'deleted_by' => $user->id]) === 0) {
                return;
            }
            $comment->forceFill(['deleted_at' => $now, 'deleted_by' => $user->id])->syncOriginal();
            $this->count($comment->run, -1);
            if ($comment->parent_id) {
                RunComment::withTrashed()->whereKey($comment->parent_id)->where('replies_count', '>', 0)->toBase()->decrement('replies_count');
            }
            $this->reportService->actionAll($comment, $user);
            $this->notifications->commentDeleted($comment);
            Realtime::send(RunCommentsChanged::comment($comment, $user));
        });
    }

    // from the admin
    public function restore(User $user, RunComment $comment): void
    {
        if (!$comment->trashed() || !$user->is_admin) {
            return;
        }
        DB::transaction(function () use ($user, $comment) {
            // (only if it is still deleted: restored twice at once, it is counted once)
            if (RunComment::onlyTrashed()->whereKey($comment->id)->update(['deleted_at' => null, 'deleted_by' => null]) === 0) {
                return;
            }
            $comment->forceFill(['deleted_at' => null, 'deleted_by' => null])->syncOriginal();
            $this->count($comment->run, 1);
            Realtime::send(RunCommentsChanged::comment($comment, $user));
            if ($comment->parent_id) {
                RunComment::withTrashed()->whereKey($comment->parent_id)->toBase()->increment('replies_count');
            }
        });
    }

    // for good, from the admin: its answers go with it (cascade)
    public function forceDelete(User $user, RunComment $comment): void
    {
        if (!$user->is_admin) {
            return;
        }
        DB::transaction(function () use ($user, $comment) {
            $gone = ($comment->trashed() ? 0 : 1) + $comment->replies()->count();
            if ($gone > 0) {
                $this->count($comment->run, -$gone);
            }
            if ($comment->parent_id && !$comment->trashed()) {
                RunComment::withTrashed()->whereKey($comment->parent_id)->where('replies_count', '>', 0)->toBase()->decrement('replies_count');
            }
            $this->reportService->actionAll($comment, $user);
            $this->notifications->commentDeleted($comment, withReplies: true);
            Realtime::send(RunCommentsChanged::comment($comment, $user));
            $comment->forceDelete();
        });
    }

    // liking twice changes nothing (one like by player)
    public function like(User $user, RunComment $comment): int
    {
        if ($comment->user_id === $user->id) {
            throw new RunCommentException('Vous ne pouvez pas aimer votre propre commentaire.');
        }
        $added = RunCommentLike::query()->insertOrIgnore([
            'comment_id' => $comment->id,
            'user_id' => $user->id,
            'created_at' => now(),
        ]);
        if ($added > 0) {
            RunComment::withTrashed()->whereKey($comment->id)->toBase()->increment('likes_count');
            $this->notifications->commentLiked($comment, $user);
        }
        $likes = (int) RunComment::withTrashed()->whereKey($comment->id)->value('likes_count');
        if ($added > 0) {
            Realtime::send(RunCommentsChanged::likes($comment, $user, $likes));
        }

        return $likes;
    }

    public function unlike(User $user, RunComment $comment): int
    {
        $removed = RunCommentLike::query()->where('comment_id', $comment->id)->where('user_id', $user->id)->delete();
        if ($removed > 0) {
            RunComment::withTrashed()->whereKey($comment->id)->where('likes_count', '>', 0)->toBase()->decrement('likes_count');
            $this->notifications->commentUnliked($comment, $user);
        }
        $likes = (int) RunComment::withTrashed()->whereKey($comment->id)->value('likes_count');
        if ($removed > 0) {
            Realtime::send(RunCommentsChanged::likes($comment, $user, $likes));
        }

        return $likes;
    }

    // one line: the line breaks and the runs of spaces become one space
    private function clean(string $content): string
    {
        $content = trim(preg_replace('/\s+/u', ' ', $content) ?? '');
        if ($content === '') {
            throw new RunCommentException('Le commentaire est vide.');
        }

        return $content;
    }

    // runs.comments_count, without touching runs.updated_at
    private function count(Run $run, int $delta): void
    {
        $query = Run::withTrashed()->whereKey($run->id)->toBase();
        if ($delta > 0) {
            $query->increment('comments_count', $delta);
        } else {
            $query->update(['comments_count' => DB::raw('CASE WHEN comments_count > '.(-$delta).' THEN comments_count - '.(-$delta).' ELSE 0 END')]);
        }
        $run->comments_count = max(0, $run->comments_count + $delta);
    }
}
