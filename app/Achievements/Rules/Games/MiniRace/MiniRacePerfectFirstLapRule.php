<?php

namespace App\Achievements\Rules\Games\MiniRace;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class MiniRacePerfectFirstLapRule extends MiniRaceRule
{
    public function achievementKey(): string
    {
        return 'perfect_first_lap';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $firstLap = data_get($event->stats, '_lp')[0] ?? null;

        return $this->best($progress, $firstLap !== null && $firstLap[1] === 1 ? 1 : 0);
    }
}
