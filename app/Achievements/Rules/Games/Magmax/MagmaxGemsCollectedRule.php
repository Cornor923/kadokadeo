<?php

namespace App\Achievements\Rules\Games\Magmax;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class MagmaxGemsCollectedRule extends MagmaxRule
{
    public function achievementKey(): string
    {
        return 'gems_collected';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $bonuses = data_get($event->stats, 'b', []);

        return AchievementRuleResult::increment($progress->current_value, min(500, $bonuses[0] + $bonuses[1] + $bonuses[2]));
    }
}
