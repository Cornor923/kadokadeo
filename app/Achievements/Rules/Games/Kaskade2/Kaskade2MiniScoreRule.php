<?php

namespace App\Achievements\Rules\Games\Kaskade2;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class Kaskade2MiniScoreRule extends Kaskade2Rule
{
    public function achievementKey(): string
    {
        return 'mini_score';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $p = $event->run->score > 2000 ? $progress->current_value : 1;

        return AchievementRuleResult::setProgress($p);
    }
}
