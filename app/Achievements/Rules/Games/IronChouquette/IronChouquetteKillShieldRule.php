<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class IronChouquetteKillShieldRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'kill_shield';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }
        $kills = data_get($event->stats, 'k', []);

        if (array_any($kills, fn ($k) => $k[0] === 500 && $k[1] > 0)) {
            return AchievementRuleResult::setProgress(1);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
