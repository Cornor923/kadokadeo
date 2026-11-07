<?php

namespace App\Achievements\Rules\Games\ChocoMouche;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class ChocoMoucheLevelReachedRule extends ChocoMoucheRule
{
    public function achievementKey(): string
    {
        return 'level_reached';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        return $this->best($progress, count(data_get($event->stats, 'd', [])));
    }
}
