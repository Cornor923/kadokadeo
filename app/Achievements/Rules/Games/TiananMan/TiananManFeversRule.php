<?php

namespace App\Achievements\Rules\Games\TiananMan;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class TiananManFeversRule extends TiananManRule
{
    public function achievementKey(): string
    {
        return 'fevers';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $fevers = data_get($event->stats, 'f', []);

        return AchievementRuleResult::setProgress(max($progress->current_value, count($fevers)));
    }
}
