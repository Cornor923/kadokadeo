<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KanjiKillStorksRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'kill_storks';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $kills = data_get($event->stats, 'k', 0);

        return AchievementRuleResult::increment($progress->current_value, $kills);
    }
}
