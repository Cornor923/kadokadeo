<?php

namespace App\Achievements\Rules\Games\F1Champion;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class F1ChampionSecondLifeRule extends F1ChampionRule
{
    public function achievementKey(): string
    {
        return 'second_life';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $lifeDroppedBelowFive = false;
        foreach (data_get($event->stats, 'l', []) as $life) {
            if ($life < 5) {
                $lifeDroppedBelowFive = true;
            } elseif ($lifeDroppedBelowFive && $life === 100) {
                return AchievementRuleResult::setProgress(1);
            }
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
