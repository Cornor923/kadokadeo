<?php

namespace App\Achievements\Rules\Games\KanjisNightmare;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KanjisNightmareRepairBrokenArmorRule extends KanjisNightmareRule
{
    public function achievementKey(): string
    {
        return 'repair_broken_armor';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $opts = data_get($event->stats, 'opt', []);
        $cnt = $opts[self::OPT_HP_UP];

        if ($cnt <= $progress->current_value) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return AchievementRuleResult::setProgress($cnt);
    }
}
