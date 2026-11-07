<?php

namespace App\Achievements\Rules\Games\ChocoMouche;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class ChocoMoucheFastLevelOneRule extends ChocoMoucheRule
{
    public function achievementKey(): string
    {
        return 'fast_level_one';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $levelOneTime = data_get($event->stats, 't.0');
        if ($levelOneTime !== null && $levelOneTime < 15 * 32) {
            return $this->best($progress, 1);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
