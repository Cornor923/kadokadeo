<?php

namespace App\Achievements\Rules\Games\Popcorn;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class PopcornBubleDestroyedInARowRule extends PopcornRule
{
    public function achievementKey(): string
    {
        return 'buble_destroyed_in_a_row';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        return $this->best($progress, $this->maxEventsBetween($event, 0, 3));
    }
}
