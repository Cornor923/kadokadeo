<?php

namespace App\Achievements\Rules\Games\ChocoMouche;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class ChocoMoucheSixAdjacentFliesRule extends ChocoMoucheRule
{
    public function achievementKey(): string
    {
        return 'six_adjacent_flies';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        foreach (data_get($event->stats, 'd', []) as $levelDiscoveries) {
            if (in_array(6, $levelDiscoveries, true)) {
                return $this->best($progress, 1);
            }
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
