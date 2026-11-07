<?php

namespace App\Achievements\Rules\Games\Tubulo;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class TubuloLevel9ChronoMaxRule extends TubuloRule
{
    public function achievementKey(): string
    {
        return 'level_9_chrono_max';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (($this->levelChronos($event)[7] ?? null) !== 0) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return $this->best($progress, 1);
    }
}
