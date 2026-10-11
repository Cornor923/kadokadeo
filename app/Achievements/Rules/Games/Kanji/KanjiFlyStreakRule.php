<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KanjiFlyStreakRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'fly_streak';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $flyStreak = data_get($event->stats, 'fs', 0);

        return AchievementRuleResult::setProgress(max($progress->current_value, intdiv($flyStreak, 32)));
    }
}
