<?php

namespace App\Achievements\Rules\Games\XianXiang;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class XianXiangPerfectPairsRule extends XianXiangRule
{
    public function achievementKey(): string
    {
        return 'perfect_pairs';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return AchievementRuleResult::setProgress(max($progress->current_value, data_get($event->stats, 'c.3')));
    }
}
