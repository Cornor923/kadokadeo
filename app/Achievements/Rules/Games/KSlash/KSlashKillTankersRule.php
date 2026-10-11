<?php

namespace App\Achievements\Rules\Games\KSlash;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KSlashKillTankersRule extends KSlashRule
{
    public function achievementKey(): string
    {
        return 'kill_tankers';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $bads = data_get($event->stats, 'k', []);

        return AchievementRuleResult::increment($progress->current_value, min(100, $bads[4]));
    }
}
