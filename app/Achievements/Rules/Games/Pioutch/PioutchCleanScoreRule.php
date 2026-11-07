<?php

namespace App\Achievements\Rules\Games\Pioutch;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class PioutchCleanScoreRule extends PioutchRule
{
    public function achievementKey(): string
    {
        return 'clean_score';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        // (-1: no bird lost and no fury, the whole score)
        $firstMistakeScore = data_get($event->stats, 'fs');

        return $this->best($progress, $firstMistakeScore < 0 ? $event->run->score : $firstMistakeScore);
    }
}
