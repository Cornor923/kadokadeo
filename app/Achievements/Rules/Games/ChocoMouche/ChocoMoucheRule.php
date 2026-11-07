<?php

namespace App\Achievements\Rules\Games\ChocoMouche;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\GameRule;
use App\Achievements\Stats;

abstract class ChocoMoucheRule extends GameRule
{
    protected const GAME = 'chocomouche';

    public function validate(GameRunCompleted $event): bool
    {
        $discoveries = data_get($event->stats, 'd', []);
        $clicks = data_get($event->stats, 'c', []);
        $points = data_get($event->stats, 'p', []);
        $times = data_get($event->stats, 't', []);

        $isDiscovery = fn (mixed $discovery): bool => is_int($discovery) && $discovery >= -2 && $discovery <= 8;
        if (!Stats::isList($discoveries, item: fn (mixed $level): bool => Stats::isList($level, item: $isDiscovery))) {
            return false;
        }
        if (!Stats::isCounts($clicks) || !Stats::isCounts($points) || !Stats::isCounts($times)) {
            return false;
        }

        if (count($discoveries) !== count($clicks) || count($points) !== count($times) || count($discoveries) !== count($points) + 1) {
            return false;
        }

        // a finished level has clicks
        return !in_array(0, array_slice($clicks, 0, count($points)), true);
    }
}
