<?php

namespace App\Achievements\Rules\Games\XianXiang;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class XianXiangNoOnePointPairRule extends XianXiangRule
{
    public function achievementKey(): string
    {
        return 'no_one_point_pair';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $p = data_get($event->stats, 'c.0') === 0 ? 1 : $progress->current_value;

        return AchievementRuleResult::setProgress($p);
    }
}
