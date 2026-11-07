<?php

namespace App\Achievements\Rules\Games\KSlash;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class KSlashNoShurikenScoreRule extends KSlashRule
{
    public function achievementKey(): string
    {
        return 'no_shuriken_score';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $firstShurikenScore = data_get($event->stats, 'fssc', -1);
        $scoreWithoutShuriken = $firstShurikenScore < 0 ? $event->run->score : $firstShurikenScore;

        return $this->best($progress, $scoreWithoutShuriken);
    }
}
