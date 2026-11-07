<?php

namespace App\Achievements\Rules\Games\ZipZap;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class ZipZapMiniScoreRule extends ZipZapRule
{
    public function achievementKey(): string
    {
        return 'mini_score';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $combo = data_get($event->stats, 'c', []);
        $c100 = $combo[0] ?? 0;

        return $this->best($progress, min(100, $c100));
    }
}
