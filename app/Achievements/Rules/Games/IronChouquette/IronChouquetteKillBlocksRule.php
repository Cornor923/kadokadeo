<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class IronChouquetteKillBlocksRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'kill_total_blocks';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $kills = data_get($event->stats, 'k', []);

        $k = array_find($kills, fn ($k) => $k[0] === 1000);
        if ($k) {
            return AchievementRuleResult::increment($progress->current_value, $k[1]);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
