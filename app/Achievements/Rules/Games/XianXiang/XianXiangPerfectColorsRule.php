<?php

namespace App\Achievements\Rules\Games\XianXiang;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class XianXiangPerfectColorsRule extends XianXiangRule
{
    public function achievementKey(): string
    {
        return 'perfect_colors';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        return $this->best($progress, min(data_get($event->stats, 'p')));
    }
}
