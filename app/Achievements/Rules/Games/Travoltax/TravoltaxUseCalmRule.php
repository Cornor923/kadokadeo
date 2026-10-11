<?php

namespace App\Achievements\Rules\Games\Travoltax;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class TravoltaxUseCalmRule extends TravoltaxRule
{
    public function achievementKey(): string
    {
        return 'use_calm';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $opts = data_get($event->stats, '_o', []);
        $calmUses = array_filter($opts, function ($opt) {
            return $opt === 5;
        });

        return AchievementRuleResult::increment($progress->current_value, min(30, count($calmUses)));
    }
}
