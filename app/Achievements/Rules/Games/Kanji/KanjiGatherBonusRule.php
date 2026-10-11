<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KanjiGatherBonusRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'gather_bonus';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $bonusCount = data_get($event->stats, 'n', 0);

        return AchievementRuleResult::increment($progress->current_value, min(500, $bonusCount));
    }
}
