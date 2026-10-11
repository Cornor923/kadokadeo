<?php

namespace App\Achievements\Rules\Games\Interwheel;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class InterwheelTotalDivesRule extends InterwheelRule
{
    public function achievementKey(): string
    {
        return 'total_dives';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $dives = data_get($event->stats, 'pl', 0);
        if ($dives > 0) {
            return AchievementRuleResult::increment($progress->current_value, min(20, $dives));
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
