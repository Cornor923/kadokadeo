<?php

namespace App\Achievements\Rules\Games\TiananMan;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class TiananManFollowersCollectedRule extends TiananManRule
{
    public function achievementKey(): string
    {
        return 'followers_collected';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $followersCollected = data_get($event->stats, 'fc', []);

        return AchievementRuleResult::increment($progress->current_value, count($followersCollected));
    }
}
