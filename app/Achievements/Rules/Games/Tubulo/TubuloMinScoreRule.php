<?php

namespace App\Achievements\Rules\Games\Tubulo;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class TubuloMinScoreRule extends TubuloRule
{
    public function achievementKey(): string
    {
        return 'min_score';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if ($event->run->score !== 200) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return $this->best($progress, 1);
    }
}
