<?php

namespace App\Achievements\Rules\Games\Opalus2;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\GameRule;
use App\Achievements\Stats;

abstract class Opalus2Rule extends GameRule
{
    protected const GAME = 'opalus2';

    public function validate(GameRunCompleted $event): bool
    {
        $turns = data_get($event->stats, 'l', []);
        $fallenByColor = data_get($event->stats, 'f', []);
        $minMax = data_get($event->stats, 'mm', []);

        if (!Stats::isRows($turns, 3) || !Stats::isRows($fallenByColor, 7) || count($fallenByColor) !== count($turns)) {
            return false;
        }

        if (!Stats::isList($minMax, 4, fn (mixed $value): bool => Stats::isCount($value) && $value <= 14)) {
            return false;
        }

        $destroyedTotal = 0;
        $fallenTotal = 0;
        foreach ($turns as $index => [$colorId, $destroyed, $fallen]) {
            if ($colorId > 6 || array_sum($fallenByColor[$index]) !== $fallen) {
                return false;
            }

            $destroyedTotal += $destroyed;
            $fallenTotal += $fallen;
            if ($destroyedTotal > 225 || $fallenTotal > 225) {
                return false;
            }
        }

        return true;
    }

    protected function turns(GameRunCompleted $event): array
    {
        return data_get($event->stats, 'l', []);
    }

    protected function fallenByColor(GameRunCompleted $event): array
    {
        return data_get($event->stats, 'f', []);
    }

    protected function minMax(GameRunCompleted $event): array
    {
        return data_get($event->stats, 'mm', []);
    }
}
