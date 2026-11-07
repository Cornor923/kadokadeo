<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class IronChouquetteSacrificesRule extends IronChouquetteRule
{
    public function achievementKey(): string
    {
        return 'sacrifices';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $bonuses = data_get($event->stats, 'b', []);

        $total = count(array_filter($bonuses, fn ($b) => $b[1] > 99));
        if ($total) {
            return $this->best($progress, $total);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
