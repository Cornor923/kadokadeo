<?php

namespace App\Achievements\Rules\Games\Interwheel;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class InterwheelTotalElevationRule extends InterwheelRule
{
    public function achievementKey(): string
    {
        return 'total_elevation';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $height = data_get($event->stats, 'hm', 0);
        if ($height > 1000) {
            return AchievementRuleResult::increment($progress->current_value, min(4500, $height));
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
