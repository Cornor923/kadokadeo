<?php

namespace App\Achievements\Rules\Games\Travoltax;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class TravoltaxUseCalmRule extends TravoltaxRule
{
    public function achievementKey(): string
    {
        return 'use_calm';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $opts = data_get($event->stats, '_o', []);
        $calmUses = array_filter($opts, function ($opt) {
            return $opt === 5;
        });

        return AchievementRuleResult::increment($progress->current_value, min(30, count($calmUses)));
    }
}
