<?php

namespace App\Achievements\Rules\Games\Travoltax;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class TravoltaxColdSweatsRule extends TravoltaxRule
{
    private const FRAMES_PER_SECOND = 32;

    private const TARGET_SECONDS = 30;

    public function achievementKey(): string
    {
        return 'cold_sweats';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $survivalSeconds = min(self::TARGET_SECONDS, intdiv(data_get($event->stats, '_t'), self::FRAMES_PER_SECOND));
        if ($survivalSeconds > $progress->current_value) {
            return AchievementRuleResult::setProgress($survivalSeconds);
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
