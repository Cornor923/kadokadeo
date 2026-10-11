<?php

namespace App\Achievements\Rules\Games\KillBulle;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KillBulleTotalBubblesPoppedRule extends KillBulleRule
{
    public function achievementKey(): string
    {
        return 'total_bubbles_popped';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $pops = data_get($event->stats, 's', 0);

        return AchievementRuleResult::increment($progress->current_value, $pops);
    }
}
