<?php

namespace App\Achievements\Rules\Games\MiniRace;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class MiniRaceSlowLapRule extends MiniRaceRule
{
    public function achievementKey(): string
    {
        return 'slow_lap';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        // (a lap of 25 seconds ends the game: between 24 and 25)
        $slow = array_filter($this->lapTimes($event), fn (int $time): bool => $time > 24000);

        return $this->best($progress, $slow === [] ? 0 : 1);
    }
}
