<?php

namespace App\Achievements\Rules\Games\Atlanteine;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class AtlanteineBonusBoxesRule extends AtlanteineRule
{
    public function achievementKey(): string
    {
        return 'bonus_boxes';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $max = 0;
        foreach ($this->finishedLevels($event) as $level) {
            if ($level[7] == 0) {
                $max = max($max, $level[0] * 200);
            }
        }

        return $this->best($progress, $max);
    }
}
