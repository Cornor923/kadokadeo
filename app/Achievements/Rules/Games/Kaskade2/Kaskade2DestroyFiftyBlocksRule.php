<?php

namespace App\Achievements\Rules\Games\Kaskade2;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class Kaskade2DestroyFiftyBlocksRule extends Kaskade2Rule
{
    public function achievementKey(): string
    {
        return 'destroy_fifty_blocks';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $blocks = data_get($event->stats, 'g', []);
        $max = max($blocks);

        return AchievementRuleResult::setProgress(max($progress->current_value, $max));
    }
}
