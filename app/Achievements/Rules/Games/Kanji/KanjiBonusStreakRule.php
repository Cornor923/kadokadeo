<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KanjiBonusStreakRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'bonus_streak';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $bonusStreak = data_get($event->stats, 'bs', 0);

        return $this->best($progress, $bonusStreak);
    }
}
