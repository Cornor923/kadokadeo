<?php

namespace App\Achievements\Rules\Games\KSlash;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KSlashSoftKillTankersRule extends KSlashRule
{
    public function achievementKey(): string
    {
        return 'soft_kill_tankers';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $softKills = data_get($event->stats, 'sk', []);

        return AchievementRuleResult::increment($progress->current_value, $softKills[4]);
    }
}
