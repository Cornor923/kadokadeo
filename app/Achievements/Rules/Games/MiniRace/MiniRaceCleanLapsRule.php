<?php

namespace App\Achievements\Rules\Games\MiniRace;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class MiniRaceCleanLapsRule extends MiniRaceRule
{
    public function achievementKey(): string
    {
        return 'clean_laps';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $cleanLaps = count(array_filter(data_get($event->stats, '_lp'), fn (array $lap): bool => $lap[0] === 0));

        return AchievementRuleResult::increment($progress->current_value, $cleanLaps);
    }
}
