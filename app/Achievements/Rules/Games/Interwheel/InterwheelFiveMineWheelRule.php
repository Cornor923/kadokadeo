<?php

namespace App\Achievements\Rules\Games\Interwheel;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class InterwheelFiveMineWheelRule extends InterwheelRule
{
    public function achievementKey(): string
    {
        return 'five_mine_wheel';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $maxMines = 0;
        foreach (data_get($event->stats, 'ws', []) as $wheel) {
            $maxMines = max($maxMines, $wheel[1]);
        }

        if ($maxMines > $progress->current_value) {
            return AchievementRuleResult::setProgress($maxMines);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
