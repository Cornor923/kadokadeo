<?php

namespace App\Achievements\Rules\Games\Bactery;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class BacteryStonesRule extends BacteryRule
{
    public function achievementKey(): string
    {
        return 'stones';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return AchievementRuleResult::setProgress(data_get($event->stats, 'w') >= 70 ? 1 : $progress->current_value);
    }
}
