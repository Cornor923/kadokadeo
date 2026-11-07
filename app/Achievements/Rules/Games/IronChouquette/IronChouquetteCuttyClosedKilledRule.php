<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class IronChouquetteCuttyClosedKilledRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'cutty_closed_killed';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $kills = data_get($event->stats, 'k', []);

        $k = array_find($kills, fn ($k) => $k[0] === 600);
        if ($k && $k[1] > $progress->current_value) {
            return AchievementRuleResult::setProgress($k[1]);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
