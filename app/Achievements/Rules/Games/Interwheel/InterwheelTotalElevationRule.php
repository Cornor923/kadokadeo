<?php

namespace App\Achievements\Rules\Games\Interwheel;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class InterwheelTotalElevationRule extends InterwheelRule
{
    public function achievementKey(): string
    {
        return 'total_elevation';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $height = data_get($event->stats, 'hm', 0);
        if ($height > 1000) {
            return AchievementRuleResult::increment($progress->current_value, min(4500, $height));
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
