<?php

namespace App\Achievements\Rules\Games\Opalus2;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class Opalus2FallenBubblesRule extends Opalus2Rule
{
    public function achievementKey(): string
    {
        return 'fallen_bubbles';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $max = max(array_map(fn (array $turn): int => $turn[2], $this->turns($event)) ?: [0]);

        return $this->best($progress, $max);
    }
}
