<?php

namespace App\Achievements\Rules\Games\Bactery;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class BacteryFewBacteriaRule extends BacteryRule
{
    public function achievementKey(): string
    {
        return 'few_bacteria';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $bacteria = data_get($event->stats, 'm');
        // the levels of the achievement: 10, 8, 6 or fewer
        $p = match (true) {
            $bacteria <= 6 => 3,
            $bacteria <= 8 => 2,
            $bacteria <= 10 => 1,
            default => 0,
        };

        return $this->best($progress, $p);
    }
}
