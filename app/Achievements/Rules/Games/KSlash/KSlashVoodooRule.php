<?php

namespace App\Achievements\Rules\Games\KSlash;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KSlashVoodooRule extends KSlashRule
{
    public function achievementKey(): string
    {
        return 'voodoo';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $opts = data_get($event->stats, 'opt', []);
        if ($opts[8] > 0) {
            return AchievementRuleResult::setProgress(1);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
