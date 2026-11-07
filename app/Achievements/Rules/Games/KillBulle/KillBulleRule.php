<?php

namespace App\Achievements\Rules\Games\KillBulle;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\GameRule;
use App\Achievements\Stats;

abstract class KillBulleRule extends GameRule
{
    protected const GAME = 'killbulle';

    public function validate(GameRunCompleted $event): bool
    {
        $bonuses = data_get($event->stats, 'b', []);
        $pops = data_get($event->stats, 's', 0);
        $poppedSizes = data_get($event->stats, 'p', []);
        $bonusPops = data_get($event->stats, 'bp', []);

        if (!Stats::isCount($pops) || !Stats::isCounts($bonuses, 4) || !Stats::isList($bonusPops, 4, fn (mixed $popsByPickup): bool => Stats::isCounts($popsByPickup))) {
            return false;
        }

        if (!Stats::isList($poppedSizes, $pops, fn (mixed $size): bool => in_array($size, [12, 25, 50, 100, 150], true))) {
            return false;
        }

        for ($bonusId = 0; $bonusId < 3; $bonusId++) {
            if (count($bonusPops[$bonusId]) !== $bonuses[$bonusId]) {
                return false;
            }
        }

        return count($bonusPops[3]) === 0;
    }
}
