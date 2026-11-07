<?php

namespace App\Achievements\Rules\Games\Tubulo;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class TubuloReachLevelRule extends TubuloRule
{
    public function achievementKey(): string
    {
        return 'reach_level';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        return $this->best($progress, count($this->completedLevels($event)) + 1);
    }
}
