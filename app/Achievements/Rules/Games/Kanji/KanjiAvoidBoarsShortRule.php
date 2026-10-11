<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KanjiAvoidBoarsShortRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'avoid_boars_short';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $bearAvoidedShort = data_get($event->stats, 'bas', 0);

        return AchievementRuleResult::setProgress(max($progress->current_value, $bearAvoidedShort));
    }
}
