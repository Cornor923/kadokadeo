<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KanjiNoStorkKillScoreRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'no_stork_kill_score';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $firstKillScore = data_get($event->stats, 'fksc', -1);
        // -1: no stork bounced on during the run
        $scoreWithoutKill = $firstKillScore < 0 ? $event->run->score : $firstKillScore;

        return AchievementRuleResult::setProgress(max($progress->current_value, $scoreWithoutKill));
    }
}
