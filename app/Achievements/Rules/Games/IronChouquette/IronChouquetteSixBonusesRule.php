<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class IronChouquetteSixBonusesRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'six_bonuses';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $diffBonuses = [];

        $this->iterateThroughBonuses($event, function ($bonusSlots) use (&$diffBonuses) {
            $bonuses = collect($bonusSlots);
            $diffBonuses = array_unique(array_merge($diffBonuses, $bonuses->filter(fn ($b) => $b !== -1)->unique()->toArray()));
        });

        return $this->best($progress, count($diffBonuses));
    }
}
