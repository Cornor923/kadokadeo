<?php

namespace App\Achievements\Rules\Games\Bactery;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class BacteryTricolorRule extends BacteryRule
{
    public function achievementKey(): string
    {
        return 'tricolor';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $bacteria = data_get($event->stats, 'm');
        $tricolor = $bacteria === data_get($event->stats, 'w') && $bacteria === data_get($event->stats, 'k');

        return AchievementRuleResult::setProgress($tricolor ? 1 : $progress->current_value);
    }
}
