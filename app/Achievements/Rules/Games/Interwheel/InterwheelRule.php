<?php

namespace App\Achievements\Rules\Games\Interwheel;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\GameRule;
use App\Achievements\Stats;

abstract class InterwheelRule extends GameRule
{
    protected const GAME = 'interwheel';

    public function validate(GameRunCompleted $event): bool
    {
        $height = data_get($event->stats, 'hm', 0);
        $jumps = data_get($event->stats, 'jp', 0);
        $dives = data_get($event->stats, 'pl', 0);
        $pastilles = data_get($event->stats, 'b', []);
        $wheelStats = data_get($event->stats, 'ws', []);
        $maxFallHeight = data_get($event->stats, 'mfh', 0);
        $waterScore = data_get($event->stats, 'was', 0);

        return Stats::isCount($height)
            && Stats::isCount($jumps)
            && Stats::isCount($dives)
            && Stats::isCounts($pastilles)
            && Stats::isCount($maxFallHeight)
            && Stats::isCount($waterScore)
            && $this->validateWheelStats($wheelStats);
    }

    protected function validateWheelStats(mixed $wheelStats): bool
    {
        return Stats::isList($wheelStats, item: fn (mixed $wheel): bool => Stats::isList($wheel, 2, is_int(...))
            && $wheel[0] >= -1 && $wheel[0] <= 98
            && Stats::isCount($wheel[1]));
    }

    protected function dodgedMines(array $wheelStats): int
    {
        return array_sum(array_map(fn (array $wheel): int => $wheel[1], $wheelStats));
    }
}
