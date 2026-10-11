<?php

namespace App\Achievements\Rules\Games\KSlash;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KSlashThreeRespawnsRule extends KSlashRule
{
    public function achievementKey(): string
    {
        return 'three_respawns';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return $this->bestProgress($progress->current_value, data_get($event->stats, 'respawn', 0));
    }
}
