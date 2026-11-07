<?php

namespace App\Achievements\Rules\Games\KanjisNightmare;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KanjisNightmareGetThreePermanentOptsRule extends KanjisNightmareRule
{
    public function achievementKey(): string
    {
        return 'get_three_permanent_opts';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $opts = array_filter(data_get($event->stats, 'opt', []), fn ($opt, $index) => $index >= self::OPT_SLASH, ARRAY_FILTER_USE_BOTH);
        $gotOpts = count(array_filter($opts, fn ($opt) => $opt > 0));

        if ($gotOpts <= $progress->current_value) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return AchievementRuleResult::setProgress($gotOpts);
    }
}
