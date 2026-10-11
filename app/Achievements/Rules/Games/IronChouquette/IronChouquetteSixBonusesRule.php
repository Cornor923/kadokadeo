<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class IronChouquetteSixBonusesRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'six_bonuses';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }
        $diffBonuses = [];

        $this->iterateThroughBonuses($event, function ($bonusSlots) use (&$diffBonuses) {
            $bonuses = collect($bonusSlots);
            $diffBonuses = array_unique(array_merge($diffBonuses, $bonuses->filter(fn ($b) => $b !== -1)->unique()->toArray()));
        });

        return AchievementRuleResult::setProgress(max($progress->current_value, count($diffBonuses)));
    }
}
