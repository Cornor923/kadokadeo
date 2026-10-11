<?php

namespace App\Achievements\Rules\Games\PiouPiou;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class PiouPiouElevationRule extends PiouPiouRule
{
    public function achievementKey(): string
    {
        return 'elevation';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $height = data_get($event->stats, 'l', 0);

        return AchievementRuleResult::setProgress(max($progress->current_value, min(300, $height)));
    }
}
