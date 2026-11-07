<?php

namespace App\Achievements\Rules\Games\XianXiang;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class XianXiangMinScoreRule extends XianXiangRule
{
    public function achievementKey(): string
    {
        return 'min_score';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $p = $event->run->score === self::PAIRS ? 1 : $progress->current_value;

        return AchievementRuleResult::setProgress($p);
    }
}
