<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KanjiKillStreakRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'kill_streak';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $killStreak = data_get($event->stats, 'ks', 0);

        return $this->best($progress, $killStreak);
    }
}
