<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KanjiKillStorksRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'kill_storks';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $kills = data_get($event->stats, 'k', 0);

        return AchievementRuleResult::increment($progress->current_value, $kills);
    }
}
