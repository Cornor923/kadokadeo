<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KanjiFlyStreakRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'fly_streak';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $flyStreak = data_get($event->stats, 'fs', 0);

        return $this->best($progress, intdiv($flyStreak, 32));
    }
}
