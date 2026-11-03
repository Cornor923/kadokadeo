<?php

namespace App\Enums;

// the preferences a player sets on his account (users.preferences, App\Models\User::prefers)
enum UserPreference: string
{
    case NOTIFY_RUN_COMMENTS = 'notify_run_comments';
    case NOTIFY_COMMENT_REPLIES = 'notify_comment_replies';
    case NOTIFY_COMMENT_LIKES = 'notify_comment_likes';

    public function default(): bool
    {
        return true;
    }

    public function label(): string
    {
        return match ($this) {
            self::NOTIFY_RUN_COMMENTS => 'Être averti quand un commentaire est posé sur un de mes replays',
            self::NOTIFY_COMMENT_REPLIES => 'Être averti des réponses à mes commentaires sur les replays',
            self::NOTIFY_COMMENT_LIKES => 'Être averti quand on aime mes commentaires sur les replays',
        };
    }
}
