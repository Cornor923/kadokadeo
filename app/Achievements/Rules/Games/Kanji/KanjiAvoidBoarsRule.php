<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KanjiAvoidBoarsRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'avoid_boars';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $bearAvoided = data_get($event->stats, 'ba', 0);

        return AchievementRuleResult::increment($progress->current_value, $bearAvoided);
    }
}
