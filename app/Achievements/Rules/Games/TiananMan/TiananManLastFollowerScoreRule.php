<?php

namespace App\Achievements\Rules\Games\TiananMan;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class TiananManLastFollowerScoreRule extends TiananManRule
{
    public function achievementKey(): string
    {
        return 'last_follower_score';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $lastFollowerScore = data_get($event->stats, 'lfsc', 0);

        return $this->best($progress, (int) $lastFollowerScore);
    }
}
