<?php

namespace App\Achievements\Rules\Games\Starfang;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class StarfangSameWeaponUpgradesRule extends StarfangRule
{
    public function achievementKey(): string
    {
        return 'same_weapon_upgrades';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $weaponUpgrades = array_filter(data_get($event->stats, 'b', []), fn ($bonus) => $bonus >= 0 && $bonus <= 4);
        $counts = array_count_values($weaponUpgrades);

        return AchievementRuleResult::setProgress(max([$progress->current_value, ...$counts]));
    }
}
