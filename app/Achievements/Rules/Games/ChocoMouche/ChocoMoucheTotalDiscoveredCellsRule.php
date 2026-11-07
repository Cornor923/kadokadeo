<?php

namespace App\Achievements\Rules\Games\ChocoMouche;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class ChocoMoucheTotalDiscoveredCellsRule extends ChocoMoucheRule
{
    public function achievementKey(): string
    {
        return 'total_discovered_cells';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $count = 0;
        foreach (data_get($event->stats, 'd', []) as $levelDiscoveries) {
            $count += count(array_filter($levelDiscoveries, fn ($discovery) => $discovery >= 0));
        }

        return AchievementRuleResult::increment($progress->current_value, $count);
    }
}
