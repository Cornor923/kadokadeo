<?php

namespace App\Achievements\Rules\Games\Popcorn;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class PopcornCombo500PtsRule extends PopcornRule
{
    private const COMBO_SCORES = [25, 50, 75, 100, 150, 200, 300, 400, 500];

    public function achievementKey(): string
    {
        return 'combo_500_pts';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        // The n-th bubble of a combo scores COMBO_SCORES[n - 1], capped at the last value (Hero.hx).
        $comboLength = $this->maxEventsBetween($event, 0, 3);
        $comboScore = $comboLength > 0 ? self::COMBO_SCORES[min($comboLength, count(self::COMBO_SCORES)) - 1] : 0;

        return $this->best($progress, $comboScore);
    }
}
