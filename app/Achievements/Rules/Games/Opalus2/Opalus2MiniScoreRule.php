<?php

namespace App\Achievements\Rules\Games\Opalus2;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class Opalus2MiniScoreRule extends Opalus2Rule
{
    public function achievementKey(): string
    {
        return 'mini_score';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $p = $event->run->score === 6750 ? 1 : $progress->current_value;

        return AchievementRuleResult::setProgress($p);
    }
}
