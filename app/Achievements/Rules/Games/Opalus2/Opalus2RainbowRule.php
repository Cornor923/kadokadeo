<?php

namespace App\Achievements\Rules\Games\Opalus2;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class Opalus2RainbowRule extends Opalus2Rule
{
    public function achievementKey(): string
    {
        return 'rainbow';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $max = 0;
        foreach ($this->fallenByColor($event) as $turn) {
            $colors = count(array_filter($turn, fn (int $fallenCount): bool => $fallenCount > 0));
            $max = max($max, $colors);
        }

        return $this->best($progress, $max);
    }
}
