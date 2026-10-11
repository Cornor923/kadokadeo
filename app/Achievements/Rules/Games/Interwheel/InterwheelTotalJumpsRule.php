<?php

namespace App\Achievements\Rules\Games\Interwheel;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class InterwheelTotalJumpsRule extends InterwheelRule
{
    public function achievementKey(): string
    {
        return 'total_jumps';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $jumps = data_get($event->stats, 'jp', 0);
        if ($jumps > 0) {
            return AchievementRuleResult::increment($progress->current_value, min(300, $jumps));
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
