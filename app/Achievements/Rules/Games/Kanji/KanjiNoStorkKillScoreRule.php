<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KanjiNoStorkKillScoreRule extends KanjiRule
{
    public function achievementKey(): string
    {
        return 'no_stork_kill_score';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $firstKillScore = data_get($event->stats, 'fksc', -1);
        // -1: no stork bounced on during the run
        $scoreWithoutKill = $firstKillScore < 0 ? $event->run->score : $firstKillScore;

        return $this->best($progress, $scoreWithoutKill);
    }
}
