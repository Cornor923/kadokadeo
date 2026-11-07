<?php

namespace App\Achievements\Rules\Games\Kaskade2;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class Kaskade2SameCellClicksRule extends Kaskade2Rule
{
    public function achievementKey(): string
    {
        return 'same_cell_clicks';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $longestSequence = 0;
        $sequence = 0;
        $previousCell = null;

        foreach ($this->clicks($event) as $click) {
            $cell = [$click[0], $click[1]];
            $sequence = $cell === $previousCell ? $sequence + 1 : 1;
            $longestSequence = max($longestSequence, $sequence);
            $previousCell = $cell;
        }

        return $this->best($progress, $longestSequence);
    }
}
