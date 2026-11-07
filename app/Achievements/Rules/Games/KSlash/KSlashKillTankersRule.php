<?php

namespace App\Achievements\Rules\Games\KSlash;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KSlashKillTankersRule extends KSlashRule
{
    public function achievementKey(): string
    {
        return 'kill_tankers';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $bads = data_get($event->stats, 'k', []);

        return AchievementRuleResult::increment($progress->current_value, min(100, $bads[4]));
    }
}
