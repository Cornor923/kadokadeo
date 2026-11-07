<?php

namespace App\Achievements\Rules\Games\Interwheel;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class InterwheelTotalDodgedEnemiesRule extends InterwheelRule
{
    public function achievementKey(): string
    {
        return 'total_dodged_enemies';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $mines = $this->dodgedMines(data_get($event->stats, 'ws', []));
        if ($mines > 0) {
            return AchievementRuleResult::increment($progress->current_value, $mines);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
