<?php

namespace App\Achievements\Rules\Games\Magmax;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class MagmaxMagmaxRule extends MagmaxRule
{
    public function achievementKey(): string
    {
        return 'magmax';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $combos = data_get($event->stats, 'c', []);

        if ($combos[3] > 0) {
            return AchievementRuleResult::setProgress(1);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
