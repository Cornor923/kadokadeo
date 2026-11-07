<?php

namespace App\Achievements\Rules\Games\F1Champion;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class F1ChampionRideOnHealRule extends F1ChampionRule
{
    public function achievementKey(): string
    {
        return 'ride_on_heal';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $b = data_get($event->stats, 'b', []);

        return $this->best($progress, $b[0] ?? 0);
    }
}
