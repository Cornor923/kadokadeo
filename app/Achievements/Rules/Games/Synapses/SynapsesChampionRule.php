<?php

namespace App\Achievements\Rules\Games\Synapses;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class SynapsesChampionRule extends SynapsesRule
{
    public function achievementKey(): string
    {
        return 'champion';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        // (the best level won: a run wins several of them)
        $best = 0;
        foreach (data_get($event->stats, 'ls', []) as $levelStats) {
            if (count($levelStats['es']) === 5 && $this->playerWinsLevel($levelStats['es'])) {
                $best = max($best, $levelStats['es'][0]);
            }
        }

        return $this->best($progress, $best);
    }
}
