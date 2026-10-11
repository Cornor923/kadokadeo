<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class IronChouquetteSacrificesRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'sacrifices';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }
        $bonuses = data_get($event->stats, 'b', []);

        $total = count(array_filter($bonuses, fn ($b) => $b[1] > 99));
        if ($total) {
            return AchievementRuleResult::setProgress(max($progress->current_value, $total));
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
