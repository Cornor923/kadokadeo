<?php

namespace App\Achievements\Rules\Games\F1Champion;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class F1ChampionRideOnHealRule extends F1ChampionRule
{
    public function achievementKey(): string
    {
        return 'ride_on_heal';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $b = data_get($event->stats, 'b', []);

        return AchievementRuleResult::setProgress(max($progress->current_value, $b[0] ?? 0));
    }
}
