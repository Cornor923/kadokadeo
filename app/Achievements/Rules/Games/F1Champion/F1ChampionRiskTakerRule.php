<?php

namespace App\Achievements\Rules\Games\F1Champion;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class F1ChampionRiskTakerRule extends F1ChampionRule
{
    public function achievementKey(): string
    {
        return 'risk_taker';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $outs = min(5, data_get($event->stats, 'o', 0));

        return $this->best($progress, $outs);
    }
}
