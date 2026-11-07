<?php

namespace App\Achievements\Rules\Games\TiananMan;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class TiananManFollowersCollectedRule extends TiananManRule
{
    public function achievementKey(): string
    {
        return 'followers_collected';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $followersCollected = data_get($event->stats, 'fc', []);

        return AchievementRuleResult::increment($progress->current_value, count($followersCollected));
    }
}
