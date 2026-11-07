<?php

namespace App\Achievements\Rules\Games\PiouPiou;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class PiouPiouNoBubbleRule extends PiouPiouRule
{
    public function achievementKey(): string
    {
        return 'no_bubble';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $firstBubbleLevel = data_get($event->stats, 'fbl', -1);
        // (no bubble: the whole climb)
        $height = $firstBubbleLevel < 0 ? data_get($event->stats, 'l', 0) : $firstBubbleLevel;

        return $this->best($progress, $height);
    }
}
