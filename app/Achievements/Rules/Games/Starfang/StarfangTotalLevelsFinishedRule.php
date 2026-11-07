<?php

namespace App\Achievements\Rules\Games\Starfang;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class StarfangTotalLevelsFinishedRule extends StarfangRule
{
    public function achievementKey(): string
    {
        return 'total_levels_finished';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        return AchievementRuleResult::increment($progress->current_value, count($this->completedLevels(data_get($event->stats, 'l', []))));
    }
}
