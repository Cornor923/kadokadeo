<?php

namespace App\Achievements\Rules\Games\ChocoMouche;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class ChocoMoucheThreeFirstFlyLossesRule extends ChocoMoucheRule
{
    public function achievementKey(): string
    {
        return 'three_first_fly_losses';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        foreach (data_get($event->stats, 'd', []) as $levelDiscoveries) {
            if (array_slice($levelDiscoveries, 0, 3) === [-1, -1, -1]) {
                return $this->best($progress, 1);
            }
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
