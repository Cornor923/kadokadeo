<?php

namespace App\Achievements\Rules\Games\ZipZap;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class ZipZapMiniScoreRule extends ZipZapRule
{
    public function achievementKey(): string
    {
        return 'mini_score';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $combo = data_get($event->stats, 'c', []);
        $c100 = $combo[0] ?? 0;

        return AchievementRuleResult::setProgress(max($progress->current_value, min(100, $c100)));
    }
}
