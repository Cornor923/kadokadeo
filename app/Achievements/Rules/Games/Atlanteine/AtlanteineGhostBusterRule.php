<?php

namespace App\Achievements\Rules\Games\Atlanteine;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class AtlanteineGhostBusterRule extends AtlanteineRule
{
    public function achievementKey(): string
    {
        return 'ghost_buster';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $ghosts = array_map(fn (array $level): int => $level[3], $this->finishedLevels($event));

        return $this->best($progress, max($ghosts ?: [0]));
    }
}
