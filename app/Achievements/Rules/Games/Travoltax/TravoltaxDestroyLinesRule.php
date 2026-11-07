<?php

namespace App\Achievements\Rules\Games\Travoltax;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class TravoltaxDestroyLinesRule extends TravoltaxRule
{
    public function achievementKey(): string
    {
        return 'destroy_lines';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $linesDestroyed = data_get($event->stats, '_l', []);

        return AchievementRuleResult::increment($progress->current_value, min(3000, array_sum($linesDestroyed)));
    }
}
