<?php

namespace App\Achievements\Rules\Games\Synapses;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class SynapsesTotalNeuronsConnectedRule extends SynapsesRule
{
    public function achievementKey(): string
    {
        return 'total_neurons_connected';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $connectedNeurons = data_get($event->stats, 'cn', []);
        $total = array_sum(array_map('count', $connectedNeurons));

        return AchievementRuleResult::increment($progress->current_value, (int) $total);
    }
}
