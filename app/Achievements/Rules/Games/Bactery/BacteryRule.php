<?php

namespace App\Achievements\Rules\Games\Bactery;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\GameRule;

abstract class BacteryRule extends GameRule
{
    // the board has 100 cells, all counted at the end of the game
    private const CELLS = 100;

    // the deal has 1 to 5 of them
    private const MAX_STARS = 5;

    protected const GAME = 'bactery';

    public function validate(GameRunCompleted $event): bool
    {
        // what is left on the board: colored marbles, bacteria, stones, stars
        $counts = [
            data_get($event->stats, 'k'),
            data_get($event->stats, 'm'),
            data_get($event->stats, 'w'),
            data_get($event->stats, 'b'),
        ];

        foreach ($counts as $count) {
            if (!is_int($count) || $count < 0) {
                return false;
            }
        }

        return array_sum($counts) === self::CELLS && $counts[3] <= self::MAX_STARS;
    }
}
