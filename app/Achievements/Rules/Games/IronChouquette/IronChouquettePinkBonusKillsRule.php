<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class IronChouquettePinkBonusKillsRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'pink_bonus_kills';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $kills = data_get($event->stats, 'spk.3', 0);

        return $this->best($progress, $kills);
    }
}
