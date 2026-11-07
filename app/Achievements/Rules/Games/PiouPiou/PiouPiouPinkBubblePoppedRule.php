<?php

namespace App\Achievements\Rules\Games\PiouPiou;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class PiouPiouPinkBubblePoppedRule extends PiouPiouRule
{
    public function achievementKey(): string
    {
        return 'pink_bubble_popped';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $bubblePopped = data_get($event->stats, 'bp', []);

        if ($bubblePopped[2] > 0) {
            return AchievementRuleResult::setProgress(1);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
