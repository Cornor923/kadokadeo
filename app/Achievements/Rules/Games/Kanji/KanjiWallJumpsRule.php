<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KanjiWallJumpsRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'wall_jumps';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $wallJumps = data_get($event->stats, 'wj', 0);

        return AchievementRuleResult::increment($progress->current_value, $wallJumps);
    }
}
