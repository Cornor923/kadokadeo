<?php

namespace App\Achievements\Rules\Games\Magmax;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class MagmaxMagmaxRule extends MagmaxRule
{
    public function achievementKey(): string
    {
        return 'magmax';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $combos = data_get($event->stats, 'c', []);

        if ($combos[3] > 0) {
            return AchievementRuleResult::setProgress(1);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
