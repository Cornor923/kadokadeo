<?php

namespace App\Achievements\Rules\Games\Magmax;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class MagmaxFlowersOneGameRule extends MagmaxRule
{
    public function achievementKey(): string
    {
        return 'flowers_one_game';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $kills = data_get($event->stats, 'k', []);

        return $this->best($progress, $kills[1]);
    }
}
