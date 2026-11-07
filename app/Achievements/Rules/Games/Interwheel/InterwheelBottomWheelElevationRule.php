<?php

namespace App\Achievements\Rules\Games\Interwheel;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class InterwheelBottomWheelElevationRule extends InterwheelRule
{
    public function achievementKey(): string
    {
        return 'bottom_wheel_elevation';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $height = data_get($event->stats, 'hm', 0);
        if ($this->landedOnBottomWheel(data_get($event->stats, 'ws', [])) && $height > $progress->current_value) {
            return AchievementRuleResult::setProgress($height);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }

    protected function landedOnBottomWheel(array $wheelStats): bool
    {
        foreach ($wheelStats as $wheel) {
            if ($wheel[0] === -1) {
                return true;
            }
        }

        return false;
    }
}
