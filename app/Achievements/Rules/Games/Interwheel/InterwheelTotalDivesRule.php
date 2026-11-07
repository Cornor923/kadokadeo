<?php

namespace App\Achievements\Rules\Games\Interwheel;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class InterwheelTotalDivesRule extends InterwheelRule
{
    public function achievementKey(): string
    {
        return 'total_dives';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $dives = data_get($event->stats, 'pl', 0);
        if ($dives > 0) {
            return AchievementRuleResult::increment($progress->current_value, min(20, $dives));
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
