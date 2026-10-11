<?php

namespace App\Achievements\Rules\Games\Interwheel;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class InterwheelWaterScoreRule extends InterwheelRule
{
    public function achievementKey(): string
    {
        return 'water_score';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $waterScore = data_get($event->stats, 'was', 0);
        if ($waterScore > $progress->current_value) {
            return AchievementRuleResult::setProgress($waterScore);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
