<?php

namespace App\Achievements\Rules\Games\XianXiang;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class XianXiangPerfectPairsRule extends XianXiangRule
{
    public function achievementKey(): string
    {
        return 'perfect_pairs';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        return $this->best($progress, data_get($event->stats, 'c.3'));
    }
}
