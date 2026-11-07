<?php

namespace App\Achievements\Rules\Games\Starfang;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class StarfangNoMainWeaponLevelsRule extends StarfangRule
{
    public function achievementKey(): string
    {
        return 'no_main_weapon_levels';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $levels = array_filter($this->completedLevels(data_get($event->stats, 'l', [])), fn ($level) => $level[5] === 0);

        return $this->best($progress, count($levels));
    }
}
