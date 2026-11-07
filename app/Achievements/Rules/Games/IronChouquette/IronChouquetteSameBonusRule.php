<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class IronChouquetteSameBonusRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'same_bonus';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $maxSameBonus = 0;

        $this->iterateThroughBonuses($event, function ($bonusSlots) use (&$maxSameBonus) {
            $bonuses = collect($bonusSlots);
            $sameBonusCount = $bonuses->filter(fn ($b) => $b !== -1)->countBy(fn ($b) => $b)->max();
            $maxSameBonus = max($maxSameBonus, $sameBonusCount);
        });

        return $this->best($progress, $maxSameBonus);
    }
}
