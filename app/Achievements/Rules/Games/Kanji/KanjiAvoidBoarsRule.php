<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KanjiAvoidBoarsRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'avoid_boars';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $bearAvoided = data_get($event->stats, 'ba', 0);

        return AchievementRuleResult::increment($progress->current_value, $bearAvoided);
    }
}
