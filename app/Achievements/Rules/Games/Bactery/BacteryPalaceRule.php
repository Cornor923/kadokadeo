<?php

namespace App\Achievements\Rules\Games\Bactery;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class BacteryPalaceRule extends BacteryRule
{
    public function achievementKey(): string
    {
        return 'palace';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $palace = data_get($event->stats, 'b') === 5 && data_get($event->stats, 'k') === 0;

        return AchievementRuleResult::setProgress($palace ? 1 : $progress->current_value);
    }
}
