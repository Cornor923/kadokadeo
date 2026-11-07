<?php

namespace App\Achievements\Rules\Games\Atlanteine;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\GameRule;
use App\Achievements\Stats;

abstract class AtlanteineRule extends GameRule
{
    protected const GAME = 'atlanteine';

    public function validate(GameRunCompleted $event): bool
    {
        $levels = data_get($event->stats, 's', []);
        if (!Stats::isRows($levels, 8)) {
            return false;
        }

        foreach ($levels as [, $ghostsInLevel, $boxesMoved, $ghostsKilledBySelf, $ghostsKilledByBlock, $timesKilledByWater, , $hasPushedInLevel]) {
            if ($boxesMoved > $timesKilledByWater + $ghostsKilledBySelf + 1 || $ghostsKilledBySelf + $ghostsKilledByBlock > $ghostsInLevel) {
                return false;
            }
            if ($hasPushedInLevel > 1) {
                return false;
            }
        }

        return true;
    }

    protected function levels(GameRunCompleted $event): array
    {
        return data_get($event->stats, 's', []);
    }

    // the last level was not finished: a game ends when the time runs out in a level
    protected function finishedLevels(GameRunCompleted $event): array
    {
        return array_slice($this->levels($event), 0, -1);
    }
}
