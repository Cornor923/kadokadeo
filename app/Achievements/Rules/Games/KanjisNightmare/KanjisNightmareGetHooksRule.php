<?php

namespace App\Achievements\Rules\Games\KanjisNightmare;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KanjisNightmareGetHooksRule extends KanjisNightmareRule
{
    public function achievementKey(): string
    {
        return 'get_hooks';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $opts = data_get($event->stats, 'opt', []);
        $cnt = $opts[self::OPT_ADD_HOOK];

        if ($cnt <= $progress->current_value) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return AchievementRuleResult::setProgress($cnt);
    }
}
