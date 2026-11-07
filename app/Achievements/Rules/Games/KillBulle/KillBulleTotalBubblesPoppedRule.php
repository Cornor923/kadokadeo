<?php

namespace App\Achievements\Rules\Games\KillBulle;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KillBulleTotalBubblesPoppedRule extends KillBulleRule
{
    public function achievementKey(): string
    {
        return 'total_bubbles_popped';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $pops = data_get($event->stats, 's', 0);

        return AchievementRuleResult::increment($progress->current_value, $pops);
    }
}
