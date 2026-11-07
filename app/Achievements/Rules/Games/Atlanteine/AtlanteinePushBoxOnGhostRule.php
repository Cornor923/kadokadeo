<?php

namespace App\Achievements\Rules\Games\Atlanteine;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class AtlanteinePushBoxOnGhostRule extends AtlanteineRule
{
    public function achievementKey(): string
    {
        return 'push_box_on_ghost';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        foreach ($this->levels($event) as $level) {
            if ($level[4] > 0) {
                return AchievementRuleResult::setProgress(1);
            }
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
