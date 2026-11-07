<?php

namespace App\Achievements\Rules\Games\Pioutch;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class PioutchVioletLostRule extends PioutchRule
{
    public function achievementKey(): string
    {
        return 'violet_lost';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        return $this->best($progress, min(1, data_get($event->stats, 'lt')[self::VIOLET]));
    }
}
