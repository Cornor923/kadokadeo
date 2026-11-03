<?php

namespace App\Events;

use App\Models\RunComment;
use App\Models\User;
use App\Support\Realtime;
use Illuminate\Broadcasting\Channel;

// the comments of a replay changed (new, answered, edited, deleted, restored), or the likes of one: the pages of the
// replay open reload its comments (what each viewer may do with them depends on him), or show the new count of likes
class RunCommentsChanged extends RealtimeEvent
{
    private function __construct(
        private readonly string $runId,
        private readonly int $commentId,
        private readonly ?User $by,
        private readonly ?int $likesCount = null,
    ) {}

    public static function comment(RunComment $comment, ?User $by): self
    {
        return new self($comment->run_id, $comment->id, $by);
    }

    public static function likes(RunComment $comment, User $by, int $likesCount): self
    {
        return new self($comment->run_id, $comment->id, $by, $likesCount);
    }

    public function broadcastOn(): Channel
    {
        return Realtime::run($this->runId);
    }

    public function broadcastAs(): string
    {
        return 'comments.changed';
    }

    public function broadcastWith(): array
    {
        return [
            'comment_id' => $this->commentId,
            // the page of the player who did it already shows it
            'by' => $this->by?->etwin_id,
            'likes_count' => $this->likesCount,
        ];
    }

    // the likes of a comment: the last count (the other changes: each, by who did it)
    public function dedupeKey(): ?string
    {
        return $this->likesCount !== null ? (string) $this->commentId : null;
    }
}
