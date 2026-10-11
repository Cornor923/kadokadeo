<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KanjiKillStreakRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'kill_streak';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $killStreak = data_get($event->stats, 'ks', 0);

        return AchievementRuleResult::setProgress(max($progress->current_value, $killStreak));
    }
}
