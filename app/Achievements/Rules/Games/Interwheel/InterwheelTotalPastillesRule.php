<?php

namespace App\Achievements\Rules\Games\Interwheel;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class InterwheelTotalPastillesRule extends InterwheelRule
{
    public function achievementKey(): string
    {
        return 'total_pastilles';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $pastilles = data_get($event->stats, 'b', []);
        if (is_array($pastilles) && count($pastilles) === 3) {
            $cnt = array_sum($pastilles);

            return AchievementRuleResult::increment($progress->current_value, min(300, $cnt));
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
