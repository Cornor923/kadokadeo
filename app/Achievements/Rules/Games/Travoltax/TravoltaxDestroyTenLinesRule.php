<?php

namespace App\Achievements\Rules\Games\Travoltax;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class TravoltaxDestroyTenLinesRule extends TravoltaxRule
{
    public function achievementKey(): string
    {
        return 'destroy_ten_lines';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        // a run without any destroyed line sends no count (max() refuses an empty array)
        $linesDestroyed = data_get($event->stats, '_l', []);
        if ($linesDestroyed === []) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }
        $maxLinesDestroyedCount = max($linesDestroyed);

        if ($maxLinesDestroyedCount <= $progress->current_value) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return AchievementRuleResult::setProgress($maxLinesDestroyedCount);
    }
}
