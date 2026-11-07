<?php

namespace App\Achievements\Rules\Games\Tubulo;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class TubuloGreenPaintRule extends TubuloRule
{
    public function achievementKey(): string
    {
        return 'green_paint';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $completedLevelCount = count($this->completedLevels($event));
        $paintedGreen = 0;
        foreach (array_slice($this->levelColors($event), 0, $completedLevelCount) as $colors) {
            $paintedGreen += $colors[1] + $colors[2];
        }

        return AchievementRuleResult::increment($progress->current_value, $paintedGreen);
    }
}
