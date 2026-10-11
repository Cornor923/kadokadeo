<?php

namespace App\Achievements\Rules\Games\PiouPiou;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class PiouPiouTotalBubblesRule extends PiouPiouRule
{
    public function achievementKey(): string
    {
        return 'total_bubbles';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $bubbles = data_get($event->stats, 'b', []);
        $sum = array_sum($bubbles);

        return AchievementRuleResult::increment($progress->current_value, min(500, $sum));
    }
}
