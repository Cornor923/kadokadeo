<?php

namespace App\Achievements\Rules\Games\Starfang;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class StarfangFastLevelRule extends StarfangRule
{
    public function achievementKey(): string
    {
        return 'fast_level';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $best = 0;
        foreach ($this->completedLevels(data_get($event->stats, 'l', [])) as $levelIndex => $level) {
            if ($levelIndex < 6) {
                continue;
            }

            $seconds = $level[6] / 32;
            $best = max($best, match (true) {
                $seconds < 15 => 3,
                $seconds < 25 => 2,
                $seconds < 35 => 1,
                default => 0,
            });
        }

        return $this->best($progress, $best);
    }
}
