<?php

namespace App\Achievements\Rules\Games\Interwheel;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class InterwheelFiveMineWheelRule extends InterwheelRule
{
    public function achievementKey(): string
    {
        return 'five_mine_wheel';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
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
