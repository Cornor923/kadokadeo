<?php

namespace App\Achievements\Rules\Games\Bactery;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class BacteryColoredMarblesRule extends BacteryRule
{
    public function achievementKey(): string
    {
        return 'colored_marbles';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return AchievementRuleResult::setProgress(data_get($event->stats, 'k') >= 85 ? 1 : $progress->current_value);
    }
}
