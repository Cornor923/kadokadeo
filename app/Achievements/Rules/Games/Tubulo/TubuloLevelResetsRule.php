<?php

namespace App\Achievements\Rules\Games\Tubulo;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class TubuloLevelResetsRule extends TubuloRule
{
    public function achievementKey(): string
    {
        return 'level_resets';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        return AchievementRuleResult::increment($progress->current_value, count(array_unique($this->resets($event))));
    }
}
