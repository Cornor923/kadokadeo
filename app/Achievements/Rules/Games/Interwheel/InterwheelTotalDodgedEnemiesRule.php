<?php

namespace App\Achievements\Rules\Games\Interwheel;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class InterwheelTotalDodgedEnemiesRule extends InterwheelRule
{
    public function achievementKey(): string
    {
        return 'total_dodged_enemies';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $mines = $this->dodgedMines(data_get($event->stats, 'ws', []));
        if ($mines > 0) {
            return AchievementRuleResult::increment($progress->current_value, $mines);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
