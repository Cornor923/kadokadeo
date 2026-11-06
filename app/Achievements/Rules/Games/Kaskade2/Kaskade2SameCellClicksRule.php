<?php

namespace App\Achievements\Rules\Games\Kaskade2;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class Kaskade2SameCellClicksRule extends Kaskade2Rule
{
    public function achievementKey(): string
    {
        return 'same_cell_clicks';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $longestSequence = 0;
        $sequence = 0;
        $previousCell = null;

        foreach ($this->clicks($event) as $click) {
            $cell = [$click[0], $click[1]];
            $sequence = $cell === $previousCell ? $sequence + 1 : 1;
            $longestSequence = max($longestSequence, $sequence);
            $previousCell = $cell;
        }

        return AchievementRuleResult::setProgress(max($progress->current_value, $longestSequence));
    }
}
