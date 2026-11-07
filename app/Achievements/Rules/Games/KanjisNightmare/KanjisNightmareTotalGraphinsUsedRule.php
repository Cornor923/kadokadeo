<?php

namespace App\Achievements\Rules\Games\KanjisNightmare;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KanjisNightmareTotalGraphinsUsedRule extends KanjisNightmareRule
{
    public function achievementKey(): string
    {
        return 'total_graphins_used';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $cnt = data_get($event->stats, 'gu', 0);

        return AchievementRuleResult::increment($progress->current_value, $cnt);
    }
}
