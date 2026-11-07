<?php

namespace App\Achievements\Rules\Games\Atlanteine;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class AtlanteineBoxesMovedRule extends AtlanteineRule
{
    public function achievementKey(): string
    {
        return 'boxes_moved';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $sum = array_sum(array_map(fn (array $level): int => $level[2], $this->levels($event)));

        return AchievementRuleResult::increment($progress->current_value, $sum);
    }
}
