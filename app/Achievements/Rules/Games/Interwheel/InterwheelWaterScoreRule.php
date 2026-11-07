<?php

namespace App\Achievements\Rules\Games\Interwheel;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class InterwheelWaterScoreRule extends InterwheelRule
{
    public function achievementKey(): string
    {
        return 'water_score';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $waterScore = data_get($event->stats, 'was', 0);
        if ($waterScore > $progress->current_value) {
            return AchievementRuleResult::setProgress($waterScore);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
