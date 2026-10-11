<?php

namespace App\Achievements\Rules\Games\KillBulle;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KillBulleTotalYingYangsRule extends KillBulleRule
{
    public function achievementKey(): string
    {
        return 'total_ying_yangs';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $bonuses = data_get($event->stats, 'b', []);

        return AchievementRuleResult::increment($progress->current_value, $bonuses[3]);
    }
}
