<?php

namespace App\Achievements\Rules\Games\Pioutch;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class PioutchSavedRule extends PioutchRule
{
    public function achievementKey(): string
    {
        return 'saved';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        return AchievementRuleResult::increment($progress->current_value, data_get($event->stats, 's'));
    }
}
