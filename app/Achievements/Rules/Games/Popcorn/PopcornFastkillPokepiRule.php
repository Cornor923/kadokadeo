<?php

namespace App\Achievements\Rules\Games\Popcorn;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class PopcornFastkillPokepiRule extends PopcornRule
{
    private const ONE_MINUTE_IN_FRAMES = 60 * 32;

    public function achievementKey(): string
    {
        return 'fastkill_pokepi';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $bossHitFrames = data_get($event->stats, 'bhf', []);
        $fastKill = count($bossHitFrames) === 7 && max($bossHitFrames) < self::ONE_MINUTE_IN_FRAMES;

        return $this->best($progress, $fastKill ? 1 : 0);
    }
}
