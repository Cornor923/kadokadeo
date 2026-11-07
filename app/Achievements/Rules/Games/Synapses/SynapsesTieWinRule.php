<?php

namespace App\Achievements\Rules\Games\Synapses;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class SynapsesTieWinRule extends SynapsesRule
{
    public function achievementKey(): string
    {
        return 'tie_win';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        foreach (data_get($event->stats, 'ls', []) as $levelStats) {
            if ($this->playerWinsLevel($levelStats['es']) && count(array_filter($levelStats['es'], fn ($score) => $score === $levelStats['es'][0])) > 1) {
                return AchievementRuleResult::setProgress(1);
            }
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
