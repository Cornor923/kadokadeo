<?php

namespace App\Achievements\Rules\Games\ZipZap;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class ZipZapEmptyShotsRule extends ZipZapRule
{
    public function achievementKey(): string
    {
        return 'empty_shots';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $emptyShots = count(array_filter(data_get($event->stats, 'pa', []), fn ($action) => array_sum($action) === 0));

        return AchievementRuleResult::increment($progress->current_value, min(10, $emptyShots));
    }
}
