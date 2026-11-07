<?php

namespace App\Achievements\Rules\Games\PiouPiou;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class PiouPiouClimbHeightRule extends PiouPiouRule
{
    public function achievementKey(): string
    {
        return 'climb_height';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $climbHeight = data_get($event->stats, 'ch', 0);

        return $this->best($progress, $climbHeight);
    }
}
