<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class IronChouquetteCuttyClosedKilledRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'cutty_closed_killed';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }
        $kills = data_get($event->stats, 'k', []);

        $k = array_find($kills, fn ($k) => $k[0] === 600);
        if ($k && $k[1] > $progress->current_value) {
            return AchievementRuleResult::setProgress($k[1]);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
