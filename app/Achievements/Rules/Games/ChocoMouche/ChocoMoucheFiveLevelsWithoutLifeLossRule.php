<?php

namespace App\Achievements\Rules\Games\ChocoMouche;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class ChocoMoucheFiveLevelsWithoutLifeLossRule extends ChocoMoucheRule
{
    public function achievementKey(): string
    {
        return 'five_levels_without_life_loss';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $discoveries = data_get($event->stats, 'd', []);
        $completedLevels = count(data_get($event->stats, 'p', []));
        $bestStreak = 0;
        $streak = 0;

        for ($level = 0; $level < $completedLevels; $level++) {
            if (in_array(-1, $discoveries[$level], true) || in_array(-2, $discoveries[$level], true)) {
                $streak = 0;

                continue;
            }

            $bestStreak = max($bestStreak, ++$streak);
        }

        return $this->best($progress, $bestStreak);
    }
}
