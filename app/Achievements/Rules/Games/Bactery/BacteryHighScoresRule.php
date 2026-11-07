<?php

namespace App\Achievements\Rules\Games\Bactery;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class BacteryHighScoresRule extends BacteryRule
{
    public function achievementKey(): string
    {
        return 'high_scores';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if ($event->run->score < 17000) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return AchievementRuleResult::increment($progress->current_value);
    }
}
