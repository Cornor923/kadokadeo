<?php

namespace App\Achievements\Rules\Games\Kaskade2;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class Kaskade2DestroyFiftyBlocksRule extends Kaskade2Rule
{
    public function achievementKey(): string
    {
        return 'destroy_fifty_blocks';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $blocks = data_get($event->stats, 'g', []);
        $max = max($blocks);

        return $this->best($progress, $max);
    }
}
