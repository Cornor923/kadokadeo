<?php

namespace App\Achievements\Rules\Games\Bactery;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class BacteryTotalStarsRule extends BacteryRule
{
    public function achievementKey(): string
    {
        return 'total_stars';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return AchievementRuleResult::increment($progress->current_value, data_get($event->stats, 'b'));
    }
}
