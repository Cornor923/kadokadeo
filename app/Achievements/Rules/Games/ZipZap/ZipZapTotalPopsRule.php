<?php

namespace App\Achievements\Rules\Games\ZipZap;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class ZipZapTotalPopsRule extends ZipZapRule
{
    public function achievementKey(): string
    {
        return 'total_pops';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $combo = data_get($event->stats, 'c', []);

        return AchievementRuleResult::increment($progress->current_value, min(100, array_sum($combo)));
    }
}
