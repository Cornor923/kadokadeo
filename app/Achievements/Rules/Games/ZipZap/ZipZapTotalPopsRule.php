<?php

namespace App\Achievements\Rules\Games\ZipZap;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class ZipZapTotalPopsRule extends ZipZapRule
{
    public function achievementKey(): string
    {
        return 'total_pops';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $combo = data_get($event->stats, 'c', []);

        return AchievementRuleResult::increment($progress->current_value, min(100, array_sum($combo)));
    }
}
