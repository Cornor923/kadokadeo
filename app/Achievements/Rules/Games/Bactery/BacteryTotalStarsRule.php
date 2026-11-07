<?php

namespace App\Achievements\Rules\Games\Bactery;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class BacteryTotalStarsRule extends BacteryRule
{
    public function achievementKey(): string
    {
        return 'total_stars';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        return AchievementRuleResult::increment($progress->current_value, data_get($event->stats, 'b'));
    }
}
