<?php

namespace App\Achievements\Rules\Games\Opalus2;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class Opalus2MiniScoreRule extends Opalus2Rule
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

        $p = $event->run->score === 6750 ? 1 : $progress->current_value;

        return AchievementRuleResult::setProgress($p);
    }
}
