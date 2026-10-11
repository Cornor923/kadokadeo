<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class IronChouquetteSameBonusRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'same_bonus';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }
        $maxSameBonus = 0;

        $this->iterateThroughBonuses($event, function ($bonusSlots) use (&$maxSameBonus) {
            $bonuses = collect($bonusSlots);
            $sameBonusCount = $bonuses->filter(fn ($b) => $b !== -1)->countBy(fn ($b) => $b)->max();
            $maxSameBonus = max($maxSameBonus, $sameBonusCount);
        });

        return AchievementRuleResult::setProgress(max($progress->current_value, $maxSameBonus));
    }
}
