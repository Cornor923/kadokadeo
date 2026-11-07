<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class IronChouquetteMaxEnemyShotsRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'max_enemy_shots';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $maxEnemyShotCount = data_get($event->stats, 'mesc', 0);

        return $this->best($progress, $maxEnemyShotCount);
    }
}
