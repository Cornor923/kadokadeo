<?php

namespace App\Settings;

use Spatie\LaravelSettings\Settings;

// the comments and the views of the replays (App\Services\RunCommentService, App\Services\RunViewService), changed from
// the admin panel (App\Filament\Pages\ManageReplaySettings); the replay page gets them with the comments
class ReplaySettings extends Settings
{
    // emergency switch: off, the comments are still shown but nobody can write new ones
    public bool $comments_enabled;

    // the length of a comment (one line), at most 1000 (run_comments.content)
    public int $comment_max_length;

    // the comments of a replay, answers included (runs.comments_count): its timeline stays readable and its page light
    // (the replay page loads them all at once)
    public int $comments_max_per_run;

    // the comments and answers of a player on a replay (against the spam)
    public int $comments_max_per_user_per_run;

    // the seconds of a replay really played (not paused, the tab visible) before it counts as a view
    public int $view_after_seconds;

    public static function group(): string
    {
        return 'replays';
    }
}
