<?php

namespace App\Achievements\Rules\Games\Travoltax;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class TravoltaxUsePsychoRule extends TravoltaxRule
{
    public function achievementKey(): string
    {
        return 'use_psycho';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $opts = data_get($event->stats, '_o', []);
        $psychoUses = array_filter($opts, function ($opt) {
            return $opt === 15;
        });

        if (count($psychoUses) <= $progress->current_value) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return AchievementRuleResult::setProgress(count($psychoUses));
    }
}
