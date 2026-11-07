<?php

namespace App\Achievements\Rules\Games\Interwheel;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class InterwheelTotalJumpsRule extends InterwheelRule
{
    public function achievementKey(): string
    {
        return 'total_jumps';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $jumps = data_get($event->stats, 'jp', 0);
        if ($jumps > 0) {
            return AchievementRuleResult::increment($progress->current_value, min(300, $jumps));
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
