<?php

namespace App\Achievements\Rules\Games\Synapses;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class SynapsesAfkRule extends SynapsesRule
{
    public function achievementKey(): string
    {
        return 'afk';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        foreach (data_get($event->stats, 'ls', []) as $k => $levelStats) {
            if ($k === 0) {
                continue;
            }
            if ($levelStats['to'] === 1 && $this->playerWinsLevel($levelStats['es'])) {
                return AchievementRuleResult::setProgress(1);
            }
        }

        return AchievementRuleResult::unchanged($progress->current_value);
    }
}
