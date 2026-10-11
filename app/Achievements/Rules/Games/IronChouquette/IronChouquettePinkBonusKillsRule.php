<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class IronChouquettePinkBonusKillsRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'pink_bonus_kills';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }
        $kills = data_get($event->stats, 'spk.3', 0);

        return AchievementRuleResult::setProgress(max($progress->current_value, $kills));
    }
}
