<?php

namespace App\Achievements\Rules\Games\XianXiang;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class XianXiangTotalTilesRule extends XianXiangRule
{
    public function achievementKey(): string
    {
        return 'total_tiles';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return AchievementRuleResult::increment($progress->current_value, self::PAIRS * 2);
    }
}
