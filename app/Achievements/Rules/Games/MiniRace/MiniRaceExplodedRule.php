<?php

namespace App\Achievements\Rules\Games\MiniRace;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class MiniRaceExplodedRule extends MiniRaceRule
{
    public function achievementKey(): string
    {
        return 'exploded';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        return $this->best($progress, data_get($event->stats, '_x'));
    }
}
