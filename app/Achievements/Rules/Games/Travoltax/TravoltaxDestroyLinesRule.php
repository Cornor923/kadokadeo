<?php

namespace App\Achievements\Rules\Games\Travoltax;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class TravoltaxDestroyLinesRule extends TravoltaxRule
{
    public function achievementKey(): string
    {
        return 'destroy_lines';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $linesDestroyed = data_get($event->stats, '_l', []);

        return AchievementRuleResult::increment($progress->current_value, min(3000, array_sum($linesDestroyed)));
    }
}
