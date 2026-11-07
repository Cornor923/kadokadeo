<?php

namespace App\Achievements\Rules\Games\Interwheel;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class InterwheelElevationRule extends InterwheelRule
{
    public function achievementKey(): string
    {
        return 'elevation';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $height = data_get($event->stats, 'hm', 0);

        if ($height <= $progress->current_value) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return AchievementRuleResult::setProgress($height);
    }
}
