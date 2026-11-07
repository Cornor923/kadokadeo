<?php

namespace App\Achievements\Rules\Games\ChocoMouche;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class ChocoMoucheLevelScoreRule extends ChocoMoucheRule
{
    public function achievementKey(): string
    {
        return 'level_score';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $points = data_get($event->stats, 'p', []);

        return $this->best($progress, $points === [] ? 0 : max($points));
    }
}
