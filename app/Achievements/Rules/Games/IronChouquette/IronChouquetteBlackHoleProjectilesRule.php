<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class IronChouquetteBlackHoleProjectilesRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'black_hole_projectiles';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $blackHoleSacrifices = data_get($event->stats, 'sak.4', []);

        $maxProjectiles = array_reduce($blackHoleSacrifices, fn ($carry, $sacrifice) => max($carry, $sacrifice[1]), 0);

        return $this->best($progress, $maxProjectiles);
    }
}
