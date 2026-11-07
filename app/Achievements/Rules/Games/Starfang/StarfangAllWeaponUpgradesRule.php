<?php

namespace App\Achievements\Rules\Games\Starfang;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class StarfangAllWeaponUpgradesRule extends StarfangRule
{
    public function achievementKey(): string
    {
        return 'all_weapon_upgrades';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $weaponUpgrades = array_unique(array_filter(data_get($event->stats, 'b', []), fn ($bonus) => $bonus >= 0 && $bonus <= 4));
        if (count($weaponUpgrades) === 5) {
            return AchievementRuleResult::setProgress(1);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
