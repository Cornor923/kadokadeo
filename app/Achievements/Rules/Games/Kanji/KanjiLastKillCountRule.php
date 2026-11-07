<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KanjiLastKillCountRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'last_kill_count';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $lastKillCount = data_get($event->stats, 'lk', 0);

        return $this->best($progress, $lastKillCount);
    }
}
