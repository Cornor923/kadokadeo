<?php

namespace App\Achievements\Rules\Games\KSlash;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KSlashShurikenStockRule extends KSlashRule
{
    public function achievementKey(): string
    {
        return 'shuriken_stock';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        return $this->best($progress, data_get($event->stats, 'maxs', 0));
    }
}
