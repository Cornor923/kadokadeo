<?php

namespace App\Achievements\Rules\Games\Kaskade2;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class Kaskade2MiniScoreRule extends Kaskade2Rule
{
    public function achievementKey(): string
    {
        return 'mini_score';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $p = $event->run->score > 2000 ? $progress->current_value : 1;

        return AchievementRuleResult::setProgress($p);
    }
}
