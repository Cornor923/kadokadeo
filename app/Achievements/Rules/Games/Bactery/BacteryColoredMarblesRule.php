<?php

namespace App\Achievements\Rules\Games\Bactery;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class BacteryColoredMarblesRule extends BacteryRule
{
    public function achievementKey(): string
    {
        return 'colored_marbles';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        return $this->best($progress, data_get($event->stats, 'k'));
    }
}
