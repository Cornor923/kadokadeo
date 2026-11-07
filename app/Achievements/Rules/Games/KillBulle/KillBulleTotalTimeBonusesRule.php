<?php

namespace App\Achievements\Rules\Games\KillBulle;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KillBulleTotalTimeBonusesRule extends KillBulleRule
{
    public function achievementKey(): string
    {
        return 'total_time_bonuses';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $bonuses = data_get($event->stats, 'b', []);

        return AchievementRuleResult::increment($progress->current_value, $bonuses[0]);
    }
}
