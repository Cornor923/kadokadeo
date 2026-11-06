<?php

namespace App\Achievements\Rules\Games\Atlanteine;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class AtlanteineGhostBusterRule extends AtlanteineRule
{
    public function achievementKey(): string
    {
        return 'ghost_buster';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $ghosts = array_map(fn (array $level): int => $level[3], $this->levels($event));

        return $this->bestProgress($progress->current_value, max($ghosts ?: [0]));
    }
}
