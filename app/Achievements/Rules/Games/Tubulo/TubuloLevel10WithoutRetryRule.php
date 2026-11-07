<?php

namespace App\Achievements\Rules\Games\Tubulo;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class TubuloLevel10WithoutRetryRule extends TubuloRule
{
    public function achievementKey(): string
    {
        return 'level_10_without_retry';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (count($this->completedLevels($event)) < 9
            || count($this->resets($event)) > 0) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return $this->best($progress, 1);
    }
}
