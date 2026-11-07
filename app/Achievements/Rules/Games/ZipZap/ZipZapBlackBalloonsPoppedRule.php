<?php

namespace App\Achievements\Rules\Games\ZipZap;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class ZipZapBlackBalloonsPoppedRule extends ZipZapRule
{
    public function achievementKey(): string
    {
        return 'black_balloons_popped';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $blackBalloonsPopped = min(1, array_sum(array_map(fn ($action) => $action[5], data_get($event->stats, 'pa', []))));

        return AchievementRuleResult::increment($progress->current_value, (int) $blackBalloonsPopped);
    }
}
