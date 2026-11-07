<?php

namespace App\Achievements\Rules\Games\Synapses;

use App\Achievements\AchievementRuleResult;
use App\Models\UserAchievementProgress;

class SynapsesCrushingVictoryRule extends SynapsesRule
{
    public function achievementKey(): string
    {
        return 'crushing_victory';
    }

    public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$this->validate($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        // (the best level won: a run wins several of them)
        $best = 0;
        foreach (data_get($event->stats, 'ls', []) as $level => $levelStats) {
            if ($level >= 2 && $this->playerWinsLevel($levelStats['es'])) {
                $best = max($best, $levelStats['es'][0]);
            }
        }

        return AchievementRuleResult::setProgress(max($progress->current_value, $best));
    }
}
