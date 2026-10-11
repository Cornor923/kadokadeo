<?php

namespace App\Achievements\Rules\Games\KanjisNightmare;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KanjisNightmareKillBlueTurtlesRule extends KanjisNightmareRule
{
    public function achievementKey(): string
    {
        return 'total_blue_turtles_killed';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $bads = data_get($event->stats, 'bads', []);

        return AchievementRuleResult::increment($progress->current_value, min(30, $bads[2]));
    }
}
