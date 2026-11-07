<?php

namespace App\Achievements\Rules\Games\F1Champion;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class F1ChampionAutobhanRule extends F1ChampionRule
{
    private const FRAMES_PER_SECOND = 32;

    public function achievementKey(): string
    {
        return 'autobhan';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $seconds = min(20, intdiv(data_get($event->stats, 'so', 0), self::FRAMES_PER_SECOND));

        return $this->best($progress, $seconds);
    }
}
