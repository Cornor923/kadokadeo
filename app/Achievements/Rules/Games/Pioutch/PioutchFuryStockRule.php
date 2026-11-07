<?php

namespace App\Achievements\Rules\Games\Pioutch;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class PioutchFuryStockRule extends PioutchRule
{
    public function achievementKey(): string
    {
        return 'fury_stock';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        return $this->best($progress, data_get($event->stats, 'mf'));
    }
}
