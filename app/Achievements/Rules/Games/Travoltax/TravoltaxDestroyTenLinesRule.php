<?php

namespace App\Achievements\Rules\Games\Travoltax;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class TravoltaxDestroyTenLinesRule extends TravoltaxRule
{
    public function achievementKey(): string
    {
        return 'destroy_ten_lines';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $linesDestroyed = data_get($event->stats, '_l', []);
        $maxLinesDestroyedCount = max($linesDestroyed);

        if ($maxLinesDestroyedCount <= $progress->current_value) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return AchievementRuleResult::setProgress($maxLinesDestroyedCount);
    }
}
