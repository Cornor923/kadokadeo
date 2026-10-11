<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class IronChouquetteKillBlocksRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'kill_total_blocks';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }
        $kills = data_get($event->stats, 'k', []);

        $k = array_find($kills, fn ($k) => $k[0] === 1000);
        if ($k) {
            return AchievementRuleResult::increment($progress->current_value, $k[1]);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
