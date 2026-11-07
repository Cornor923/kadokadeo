<?php

namespace App\Achievements\Rules\Games\Synapses;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\GameRule;
use App\Achievements\Stats;

abstract class SynapsesRule extends GameRule
{
    protected const GAME = 'synapses';

    public function validate(GameRunCompleted $event): bool
    {
        $connectedNeurons = data_get($event->stats, 'cn', []);
        $levelStats = data_get($event->stats, 'ls', []);

        if (!Stats::isList($connectedNeurons) || !Stats::isList($levelStats) || count($connectedNeurons) !== count($levelStats)) {
            return false;
        }

        foreach ($connectedNeurons as $level => $levelConnectedNeurons) {
            if (!Stats::isCounts($levelConnectedNeurons) || count($levelConnectedNeurons) > 80) {
                return false;
            }

            $stats = $levelStats[$level];
            if (!is_array($stats) || !in_array($stats['to'] ?? null, [0, 1], true)) {
                return false;
            }

            $enemyScores = $stats['es'] ?? null;
            if (!Stats::isCounts($enemyScores) || count($enemyScores) < 1 || count($enemyScores) > 5) {
                return false;
            }

            if ($enemyScores[0] !== count($levelConnectedNeurons)) {
                return false;
            }
        }

        return true;
    }

    protected function playerWinsLevel(array $scores): bool
    {
        return count($scores) > 0 && $scores[0] === max($scores);
    }
}
