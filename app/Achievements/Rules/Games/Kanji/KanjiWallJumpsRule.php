<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KanjiWallJumpsRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'wall_jumps';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $wallJumps = data_get($event->stats, 'wj', 0);

        return AchievementRuleResult::increment($progress->current_value, $wallJumps);
    }
}
