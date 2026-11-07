<?php

namespace App\Achievements\Rules\Games\ZipZap;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class ZipZapFastFinishRule extends ZipZapRule
{
    public function achievementKey(): string
    {
        return 'fast_finish';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $moves = data_get($event->stats, 'm', 0);
        $blackBalloonsPopped = array_sum(array_map(fn ($action) => $action[5], data_get($event->stats, 'pa', [])));

        if ($blackBalloonsPopped === 0 && $moves < 23) {
            return AchievementRuleResult::setProgress(1);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
