<?php

namespace App\Achievements\Rules\Games\XianXiang;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class XianXiangNoOnePointPairRule extends XianXiangRule
{
    public function achievementKey(): string
    {
        return 'no_one_point_pair';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $p = data_get($event->stats, 'c.0') === 0 ? 1 : $progress->current_value;

        return AchievementRuleResult::setProgress($p);
    }
}
