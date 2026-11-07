<?php

namespace App\Achievements\Rules\Games\F1Champion;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class F1ChampionPilotRule extends F1ChampionRule
{
    private const DISTANCE_UNITS_PER_KM = 25;

    public function achievementKey(): string
    {
        return 'pilot';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $km = min(10, intdiv(data_get($event->stats, 'm', 0), self::DISTANCE_UNITS_PER_KM));

        return $this->best($progress, $km);
    }
}
