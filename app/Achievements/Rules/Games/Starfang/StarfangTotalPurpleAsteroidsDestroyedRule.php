<?php

namespace App\Achievements\Rules\Games\Starfang;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class StarfangTotalPurpleAsteroidsDestroyedRule extends StarfangRule
{
    public function achievementKey(): string
    {
        return 'total_purple_asteroids_destroyed';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $purpleAsteroids = array_sum(array_map(fn ($level) => $level[2], data_get($event->stats, 'l', [])));

        return AchievementRuleResult::increment($progress->current_value, (int) $purpleAsteroids);
    }
}
