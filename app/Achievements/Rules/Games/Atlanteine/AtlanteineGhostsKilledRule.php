<?php

namespace App\Achievements\Rules\Games\Atlanteine;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class AtlanteineGhostsKilledRule extends AtlanteineRule
{
    public function achievementKey(): string
    {
        return 'ghosts_killed';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $sum = array_sum(array_map(fn (array $level): int => $level[3] + $level[4], $this->levels($event)));

        return AchievementRuleResult::increment($progress->current_value, $sum);
    }
}
