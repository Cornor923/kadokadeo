<?php

namespace App\Achievements\Rules\Games\KanjisNightmare;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KanjisNightmareTurtlesKilledRule extends KanjisNightmareRule
{
    public function achievementKey(): string
    {
        return 'turtles_killed';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $bads = data_get($event->stats, 'bads', []);
        $cnt = array_sum($bads);

        if ($cnt <= $progress->current_value) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return AchievementRuleResult::setProgress($cnt);
    }
}
