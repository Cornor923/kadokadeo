<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KanjiAvoidBoarsShortRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'avoid_boars_short';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $bearAvoidedShort = data_get($event->stats, 'bas', 0);

        return $this->best($progress, $bearAvoidedShort);
    }
}
