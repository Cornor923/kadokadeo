<?php

namespace App\Achievements\Rules\Games\Interwheel;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class InterwheelMaxFallHeightRule extends InterwheelRule
{
    public function achievementKey(): string
    {
        return 'max_fall_height';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $maxFallHeight = data_get($event->stats, 'mfh', 0);
        if ($maxFallHeight > $progress->current_value) {
            return AchievementRuleResult::setProgress($maxFallHeight);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
