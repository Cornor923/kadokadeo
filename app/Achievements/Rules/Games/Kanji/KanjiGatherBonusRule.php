<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KanjiGatherBonusRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'gather_bonus';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $bonusCount = data_get($event->stats, 'n', 0);

        return AchievementRuleResult::increment($progress->current_value, min(500, $bonusCount));
    }
}
