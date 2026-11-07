<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class IronChouquetteKillStormsRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'kill_storms';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $kills = data_get($event->stats, 'k', []);

        $k = array_filter($kills, fn ($k) => in_array($k[0], [2000, 3500, 8000]));
        $total = array_reduce($k, fn ($carry, $k) => $carry + $k[1], 0);
        if ($total > $progress->current_value) {
            return AchievementRuleResult::setProgress($total);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
