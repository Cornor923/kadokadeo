<?php

namespace App\Achievements\Rules\Games\Kaskade2;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class Kaskade2SameColorClicksRule extends Kaskade2Rule
{
    public function achievementKey(): string
    {
        return 'same_color_clicks';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $longestSequence = 0;
        $currentSequence = 0;
        $previousColor = null;

        foreach ($this->clicks($event) as $click) {
            $color = $click[2];
            $currentSequence = $color === $previousColor ? $currentSequence + 1 : 1;
            $longestSequence = max($longestSequence, $currentSequence);
            $previousColor = $color;
        }

        return $this->best($progress, $longestSequence);
    }
}
