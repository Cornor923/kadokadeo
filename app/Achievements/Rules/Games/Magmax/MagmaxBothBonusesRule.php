<?php

namespace App\Achievements\Rules\Games\Magmax;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class MagmaxBothBonusesRule extends MagmaxRule
{
    public function achievementKey(): string
    {
        return 'both_bonuses';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (data_get($event->stats, 'dual', 0) > 0) {
            return AchievementRuleResult::setProgress(1);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
