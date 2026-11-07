<?php

namespace App\Achievements\Rules\Games\TiananMan;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class TiananManNoFollowerLostFeverRule extends TiananManRule
{
    public function achievementKey(): string
    {
        return 'no_follower_lost_fever';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $fevers = data_get($event->stats, 'f', []);
        $followersLost = data_get($event->stats, 'fl', []);

        if (count($fevers) > 0 && $fevers[0] < $followersLost[0]) {
            return AchievementRuleResult::setProgress(1);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
