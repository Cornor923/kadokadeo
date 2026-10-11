<?php

namespace App\Achievements\Rules\Games\ChocoMouche;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class ChocoMoucheFiveLevelsWithoutLifeLossRule extends ChocoMoucheRule
{
    public function achievementKey(): string
    {
        return 'five_levels_without_life_loss';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

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

        return $this->bestProgress($progress->current_value, $bestStreak);
    }
}
