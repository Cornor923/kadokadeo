<?php

namespace App\Achievements\Rules\Games\KanjisNightmare;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KanjisNightmareTurtlesKilledRule extends KanjisNightmareRule
{
    public function achievementKey(): string
    {
        return 'turtles_killed';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $bads = data_get($event->stats, 'bads', []);
        $cnt = array_sum($bads);

        if ($cnt <= $progress->current_value) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return AchievementRuleResult::setProgress($cnt);
    }
}
