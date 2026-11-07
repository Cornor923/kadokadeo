<?php

namespace App\Achievements\Rules\Games\PiouPiou;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class PiouPiouTotalBubblesRule extends PiouPiouRule
{
    public function achievementKey(): string
    {
        return 'total_bubbles';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $bubbles = data_get($event->stats, 'b', []);
        $sum = array_sum($bubbles);

        return AchievementRuleResult::increment($progress->current_value, min(500, $sum));
    }
}
