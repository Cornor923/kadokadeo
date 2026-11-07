<?php

namespace App\Achievements\Rules\Games\ChocoMouche;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class ChocoMoucheSevenClicksLevelRule extends ChocoMoucheRule
{
    public function achievementKey(): string
    {
        return 'seven_clicks_level';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $clicks = data_get($event->stats, 'c', []);
        $completedLevels = count(data_get($event->stats, 'p', []));

        for ($level = 0; $level < $completedLevels; $level++) {
            if ($clicks[$level] <= 7) {
                return $this->best($progress, 1);
            }
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
