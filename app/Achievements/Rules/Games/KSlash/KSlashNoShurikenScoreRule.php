<?php

namespace App\Achievements\Rules\Games\KSlash;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class KSlashNoShurikenScoreRule extends KSlashRule
{
    public function achievementKey(): string
    {
        return 'no_shuriken_score';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        $firstShurikenScore = data_get($event->stats, 'fssc', 0);
        $scoreWithoutShuriken = $firstShurikenScore === 0 ? $event->run->score : $firstShurikenScore;

        return $this->bestProgress($progress->current_value, $scoreWithoutShuriken);
    }
}
