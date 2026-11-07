<?php

namespace App\Achievements\Rules\Games\Popcorn;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class PopcornTotalBubleDestroyedRule extends PopcornRule
{
    public function achievementKey(): string
    {
        return 'total_buble_destroyed';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        return AchievementRuleResult::increment($progress->current_value, $this->eventCount($event, 0));
    }
}
