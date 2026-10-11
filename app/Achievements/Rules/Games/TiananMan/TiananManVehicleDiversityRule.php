<?php

namespace App\Achievements\Rules\Games\TiananMan;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class TiananManVehicleDiversityRule extends TiananManRule
{
    public function achievementKey(): string
    {
        return 'vehicle_diversity';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $vehiclesDestroyed = data_get($event->stats, 'vd', []);
        $count = count(array_filter($vehiclesDestroyed, fn ($value) => $value > 0));

        if ($count > $progress->current_value) {
            return AchievementRuleResult::setProgress($count);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
