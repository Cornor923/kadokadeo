<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KanjiLastKillCountRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'last_kill_count';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $lastKillCount = data_get($event->stats, 'lk', 0);

        return AchievementRuleResult::setProgress(max($progress->current_value, $lastKillCount));
    }
}
