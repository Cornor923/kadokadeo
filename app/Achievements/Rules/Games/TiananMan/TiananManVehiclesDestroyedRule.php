<?php

namespace App\Achievements\Rules\Games\TiananMan;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class TiananManVehiclesDestroyedRule extends TiananManRule
{
    public function achievementKey(): string
    {
        return 'vehicles_destroyed';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $vehiclesDestroyed = data_get($event->stats, 'vd', []);

        return AchievementRuleResult::increment($progress->current_value, (int) array_sum($vehiclesDestroyed));
    }
}
