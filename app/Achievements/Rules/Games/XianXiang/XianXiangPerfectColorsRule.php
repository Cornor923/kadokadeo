<?php

namespace App\Achievements\Rules\Games\XianXiang;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class XianXiangPerfectColorsRule extends XianXiangRule
{
    public function achievementKey(): string
    {
        return 'perfect_colors';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $p = min(data_get($event->stats, 'p')) >= 2 ? 1 : $progress->current_value;

        return AchievementRuleResult::setProgress($p);
    }
}
