<?php

namespace App\Achievements\Rules\Games\Magmax;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class MagmaxFlowersOneGameRule extends MagmaxRule
{
    public function achievementKey(): string
    {
        return 'flowers_one_game';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $kills = data_get($event->stats, 'k', []);

        return $this->bestProgress($progress->current_value, $kills[1]);
    }
}
