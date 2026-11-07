<?php

namespace App\Achievements\Rules\Games\Atlanteine;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class AtlanteineBonusBoxesRule extends AtlanteineRule
{
    public function achievementKey(): string
    {
        return 'bonus_boxes';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $max = 0;
        foreach ($this->finishedLevels($event) as $level) {
            if ($level[7] == 0) {
                $max = max($max, $level[0] * 200);
            }
        }

        return $this->bestProgress($progress->current_value, $max);
    }
}
