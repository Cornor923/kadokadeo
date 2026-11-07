<?php

namespace App\Achievements\Rules\Games\MiniRace;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class MiniRaceFastLapRule extends MiniRaceRule
{
    public function achievementKey(): string
    {
        return 'fast_lap';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        // the levels of the achievement: a lap under 10, 9 or 8 seconds
        $best = min([...$this->lapTimes($event), PHP_INT_MAX]);

        return $this->best($progress, match (true) {
            $best < 8000 => 3,
            $best < 9000 => 2,
            $best < 10000 => 1,
            default => 0,
        });
    }
}
