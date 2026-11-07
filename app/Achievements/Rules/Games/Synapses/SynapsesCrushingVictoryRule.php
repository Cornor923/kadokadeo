<?php

namespace App\Achievements\Rules\Games\Synapses;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class SynapsesCrushingVictoryRule extends SynapsesRule
{
    public function achievementKey(): string
    {
        return 'crushing_victory';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        // (the best level won: a run wins several of them)
        $best = 0;
        foreach (data_get($event->stats, 'ls', []) as $level => $levelStats) {
            if ($level >= 2 && $this->playerWinsLevel($levelStats['es'])) {
                $best = max($best, $levelStats['es'][0]);
            }
        }

        return $this->best($progress, $best);
    }
}
