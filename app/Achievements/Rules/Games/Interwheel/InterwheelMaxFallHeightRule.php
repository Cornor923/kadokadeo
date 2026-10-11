<?php

namespace App\Achievements\Rules\Games\Interwheel;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class InterwheelMaxFallHeightRule extends InterwheelRule
{
    public function achievementKey(): string
    {
        return 'max_fall_height';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $maxFallHeight = data_get($event->stats, 'mfh', 0);
        if ($maxFallHeight > $progress->current_value) {
            return AchievementRuleResult::setProgress($maxFallHeight);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
