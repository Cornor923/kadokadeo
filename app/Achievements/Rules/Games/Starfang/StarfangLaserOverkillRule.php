<?php

namespace App\Achievements\Rules\Games\Starfang;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class StarfangLaserOverkillRule extends StarfangRule
{
    public function achievementKey(): string
    {
        return 'laser_overkill';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $killsByBonus = data_get($event->stats, 'kb', []);
        if ($killsByBonus[10] > 0) {
            return AchievementRuleResult::setProgress(1);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
