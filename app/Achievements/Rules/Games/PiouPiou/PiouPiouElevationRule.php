<?php

namespace App\Achievements\Rules\Games\PiouPiou;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class PiouPiouElevationRule extends PiouPiouRule
{
    public function achievementKey(): string
    {
        return 'elevation';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $height = data_get($event->stats, 'l', 0);

        return $this->best($progress, min(300, $height));
    }
}
