<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class IronChouquetteMaxEnemyShotsRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'max_enemy_shots';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }
        $maxEnemyShotCount = data_get($event->stats, 'mesc', 0);

        return AchievementRuleResult::setProgress(max($progress->current_value, $maxEnemyShotCount));
    }
}
