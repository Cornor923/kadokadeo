<?php

namespace App\Achievements\Rules\Games\TiananMan;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class TiananManFeversRule extends TiananManRule
{
    public function achievementKey(): string
    {
        return 'fevers';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $fevers = data_get($event->stats, 'f', []);

        return $this->best($progress, count($fevers));
    }
}
