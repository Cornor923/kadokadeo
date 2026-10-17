<?php

namespace App\Achievements\Rules\Games\Magmax;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class MagmaxTurretsKilledRule extends MagmaxRule
{
    public function achievementKey(): string
    {
        return 'turrets_killed';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $kills = data_get($event->stats, 'k', []);

        return AchievementRuleResult::increment($progress->current_value, min(500, $kills[2]));
    }
}
