<?php

namespace App\Achievements\Rules\Games\Kaskade2;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class Kaskade2TotalBlocksRule extends Kaskade2Rule
{
    public function achievementKey(): string
    {
        return 'total_blocks';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $blocks = data_get($event->stats, 'g', []);
        $sum = array_sum($blocks);

        return AchievementRuleResult::increment($progress->current_value, $sum);
    }
}
