<?php

namespace App\Achievements\Rules\Games\XianXiang;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class XianXiangMinScoreRule extends XianXiangRule
{
    public function achievementKey(): string
    {
        return 'min_score';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $p = $event->run->score === self::PAIRS ? 1 : $progress->current_value;

        return AchievementRuleResult::setProgress($p);
    }
}
