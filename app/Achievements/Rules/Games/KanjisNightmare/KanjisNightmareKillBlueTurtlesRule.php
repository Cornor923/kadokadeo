<?php

namespace App\Achievements\Rules\Games\KanjisNightmare;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KanjisNightmareKillBlueTurtlesRule extends KanjisNightmareRule
{
    public function achievementKey(): string
    {
        return 'total_blue_turtles_killed';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $bads = data_get($event->stats, 'bads', []);

        return AchievementRuleResult::increment($progress->current_value, min(30, $bads[2]));
    }
}
