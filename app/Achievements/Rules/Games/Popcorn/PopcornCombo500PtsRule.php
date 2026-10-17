<?php

namespace App\Achievements\Rules\Games\Popcorn;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class PopcornCombo500PtsRule extends PopcornRule
{
    private const COMBO_SCORES = [25, 50, 75, 100, 150, 200, 300, 400, 500];

    public function achievementKey(): string
    {
        return 'combo_500_pts';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        // The n-th bubble of a combo scores COMBO_SCORES[n - 1], capped at the last value (Hero.hx).
        $comboLength = $this->maxEventsBetween($event, 0, 3);
        $comboScore = $comboLength > 0 ? self::COMBO_SCORES[min($comboLength, count(self::COMBO_SCORES)) - 1] : 0;

        return $this->bestProgress($progress->current_value, $comboScore);
    }
}
