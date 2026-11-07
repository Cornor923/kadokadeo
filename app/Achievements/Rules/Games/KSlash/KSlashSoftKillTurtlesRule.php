<?php

namespace App\Achievements\Rules\Games\KSlash;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KSlashSoftKillTurtlesRule extends KSlashRule
{
    public function achievementKey(): string
    {
        return 'soft_kill_turtles';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $softKills = data_get($event->stats, 'sk', []);

        return AchievementRuleResult::increment($progress->current_value, $softKills[0] + $softKills[1] + $softKills[2]);
    }
}
