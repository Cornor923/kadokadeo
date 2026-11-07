<?php

namespace App\Achievements\Rules\Games\KSlash;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KSlashVoodooRule extends KSlashRule
{
    public function achievementKey(): string
    {
        return 'voodoo';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $opts = data_get($event->stats, 'opt', []);
        if ($opts[8] > 0) {
            return AchievementRuleResult::setProgress(1);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
