<?php

namespace App\Achievements\Rules\Games\KanjisNightmare;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KanjisNightmareGetThreePermanentOptsRule extends KanjisNightmareRule
{
    public function achievementKey(): string
    {
        return 'get_three_permanent_opts';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $opts = array_filter(data_get($event->stats, 'opt', []), fn ($opt, $index) => $index >= self::OPT_SLASH, ARRAY_FILTER_USE_BOTH);
        $gotOpts = count(array_filter($opts, fn ($opt) => $opt > 0));

        if ($gotOpts <= $progress->current_value) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return AchievementRuleResult::setProgress($gotOpts);
    }
}
