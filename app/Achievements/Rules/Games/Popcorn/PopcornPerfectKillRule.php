<?php

namespace App\Achievements\Rules\Games\Popcorn;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class PopcornPerfectKillRule extends PopcornRule
{
    public function achievementKey(): string
    {
        return 'perfect_kill';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $perfectKill = $this->eventCount($event, 2) === 7 && $this->eventCount($event, 1) === 0;

        return $this->best($progress, $perfectKill ? 1 : 0);
    }
}
