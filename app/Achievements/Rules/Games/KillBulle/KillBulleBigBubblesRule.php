<?php

namespace App\Achievements\Rules\Games\KillBulle;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KillBulleBigBubblesRule extends KillBulleRule
{
    public function achievementKey(): string
    {
        return 'big_bubbles';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $bigBubbles = count(array_filter(data_get($event->stats, 'p', []), fn ($size) => $size === 150));

        if ($bigBubbles <= $progress->current_value) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return AchievementRuleResult::setProgress($bigBubbles);
    }
}
