<?php

namespace App\Achievements\Rules\Games\XianXiang;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class XianXiangPerfectNeighboursRule extends XianXiangRule
{
    public function achievementKey(): string
    {
        return 'perfect_neighbours';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        return AchievementRuleResult::increment($progress->current_value, data_get($event->stats, 'n'));
    }
}
