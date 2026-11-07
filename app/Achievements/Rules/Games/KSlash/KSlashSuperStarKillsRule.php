<?php

namespace App\Achievements\Rules\Games\KSlash;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KSlashSuperStarKillsRule extends KSlashRule
{
    public function achievementKey(): string
    {
        return 'super_star_kills';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        return AchievementRuleResult::increment($progress->current_value, data_get($event->stats, 'supak', 0));
    }
}
