<?php

namespace App\Achievements\Rules\Games\Synapses;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class SynapsesNeuronScoreRule extends SynapsesRule
{
    public function achievementKey(): string
    {
        return 'neuron_score';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $connectedNeurons = data_get($event->stats, 'cn', []);
        $max = 0;
        foreach ($connectedNeurons as $levelConnectedNeurons) {
            if (count($levelConnectedNeurons) > 0) {
                $max = max($max, max($levelConnectedNeurons));
            }
        }

        return $this->best($progress, $max);
    }
}
