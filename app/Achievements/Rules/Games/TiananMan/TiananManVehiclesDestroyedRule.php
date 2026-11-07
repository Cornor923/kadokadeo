<?php

namespace App\Achievements\Rules\Games\TiananMan;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class TiananManVehiclesDestroyedRule extends TiananManRule
{
    public function achievementKey(): string
    {
        return 'vehicles_destroyed';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $vehiclesDestroyed = data_get($event->stats, 'vd', []);

        return AchievementRuleResult::increment($progress->current_value, (int) array_sum($vehiclesDestroyed));
    }
}
