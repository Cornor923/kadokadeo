<?php

namespace App\Achievements\Rules\Games\Bactery;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class BacteryTricolorRule extends BacteryRule
{
    public function achievementKey(): string
    {
        return 'tricolor';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $bacteria = data_get($event->stats, 'm');
        $tricolor = $bacteria === data_get($event->stats, 'w') && $bacteria === data_get($event->stats, 'k');

        return AchievementRuleResult::setProgress($tricolor ? 1 : $progress->current_value);
    }
}
