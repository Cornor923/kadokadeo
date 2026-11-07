<?php

namespace App\Achievements\Rules\Games\PiouPiou;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class PiouPiouTotalElevationRule extends PiouPiouRule
{
    public function achievementKey(): string
    {
        return 'total_elevation';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $height = data_get($event->stats, 'l', 0);

        return AchievementRuleResult::increment($progress->current_value, min(300, $height));
    }
}
