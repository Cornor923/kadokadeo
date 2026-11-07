<?php

namespace App\Achievements\Rules\Games\Synapses;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class SynapsesLevelOneScoreRule extends SynapsesRule
{
    public function achievementKey(): string
    {
        return 'level_one_score';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $levelOneConnectedNeurons = data_get($event->stats, 'cn.0', []);

        return $this->best($progress, array_sum($levelOneConnectedNeurons));
    }
}
