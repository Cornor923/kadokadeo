<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KanjiBonusStreakRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'bonus_streak';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $bonusStreak = data_get($event->stats, 'bs', 0);

        return AchievementRuleResult::setProgress(max($progress->current_value, $bonusStreak));
    }
}
