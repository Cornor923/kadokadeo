<?php

namespace App\Achievements\Rules\Games\Kaskade2;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class Kaskade2TotalBlocksRule extends Kaskade2Rule
{
    public function achievementKey(): string
    {
        return 'total_blocks';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $blocks = data_get($event->stats, 'g', []);
        $sum = array_sum($blocks);

        return AchievementRuleResult::increment($progress->current_value, $sum);
    }
}
