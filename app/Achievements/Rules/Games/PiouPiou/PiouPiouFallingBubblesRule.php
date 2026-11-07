<?php

namespace App\Achievements\Rules\Games\PiouPiou;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class PiouPiouFallingBubblesRule extends PiouPiouRule
{
    public function achievementKey(): string
    {
        return 'falling_bubbles';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $fallingBubbles = data_get($event->stats, 'fb', []);

        return $this->best($progress, array_sum($fallingBubbles));
    }
}
