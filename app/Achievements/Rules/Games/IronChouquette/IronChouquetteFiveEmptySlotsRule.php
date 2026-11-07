<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class IronChouquetteFiveEmptySlotsRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'five_empty_slots';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $maxSlotsEmpty = 0;

        $this->iterateThroughBonuses($event, function ($bonusSlots) use (&$maxSlotsEmpty) {
            $maxSlotsEmpty = max($maxSlotsEmpty, count(array_filter($bonusSlots, fn ($s) => $s === -1)));
        });

        return $this->best($progress, $maxSlotsEmpty);
    }
}
