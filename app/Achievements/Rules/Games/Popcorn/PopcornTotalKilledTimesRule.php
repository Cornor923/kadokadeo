<?php

namespace App\Achievements\Rules\Games\Popcorn;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class PopcornTotalKilledTimesRule extends PopcornRule
{
    public function achievementKey(): string
    {
        return 'total_killed_times';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        return AchievementRuleResult::increment($progress->current_value, $this->eventCount($event, 2) === 7 ? 1 : 0);
    }
}
