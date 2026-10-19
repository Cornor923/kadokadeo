<?php

namespace App\Services;

use App\Models\Run;
use App\Models\RunView;
use App\Models\User;

// The views of a replay: one by player who watched it (the replay page sends it after App\Settings\ReplaySettings::
// view_after_seconds of replay really played), its own player not counted. Reloading the page or watching again adds
// nothing: runs.views_count only grows with a new player.
class RunViewService
{
    // true when it is a new view
    public function record(User $user, Run $run): bool
    {
        if ($run->user_id === $user->id) {
            return false;
        }
        $added = RunView::query()->insertOrIgnore([
            'run_id' => $run->id,
            'user_id' => $user->id,
            'created_at' => now(),
        ]);
        if ($added === 0) {
            return false;
        }
        // without touching runs.updated_at
        Run::withTrashed()->whereKey($run->id)->toBase()->increment('views_count');

        return true;
    }
}
