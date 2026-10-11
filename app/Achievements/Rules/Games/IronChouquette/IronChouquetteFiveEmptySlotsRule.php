<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class IronChouquetteFiveEmptySlotsRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'five_empty_slots';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }
        $maxSlotsEmpty = 0;

        $this->iterateThroughBonuses($event, function ($bonusSlots) use (&$maxSlotsEmpty) {
            $maxSlotsEmpty = max($maxSlotsEmpty, count(array_filter($bonusSlots, fn ($s) => $s === -1)));
        });

        return AchievementRuleResult::setProgress(max($progress->current_value, $maxSlotsEmpty));
    }
}
