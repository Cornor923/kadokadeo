<?php

namespace App\Achievements\Rules\Games\TiananMan;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class TiananManLastFollowerScoreRule extends TiananManRule
{
    public function achievementKey(): string
    {
        return 'last_follower_score';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $lastFollowerScore = data_get($event->stats, 'lfsc', 0);

        return AchievementRuleResult::setProgress(max($progress->current_value, (int) $lastFollowerScore));
    }
}
