<?php

namespace App\Achievements\Rules\Games\XianXiang;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\GameRule;
use App\Achievements\Stats;

abstract class XianXiangRule extends GameRule
{
    // the 42 cards of the board: a game only ends once they are all gone
    protected const PAIRS = 21;

    protected const GAME = 'xianxiang';

    public function validate(GameRunCompleted $event): bool
    {
        // the pairs by attributes in common (3: the perfect pairs)
        $pairs = data_get($event->stats, 'c');
        // the perfect pairs by color
        $colors = data_get($event->stats, 'p');
        // the perfect pairs on neighbouring cells
        $neighbours = data_get($event->stats, 'n');

        if (!Stats::isCounts($pairs, 4) || array_sum($pairs) !== self::PAIRS) {
            return false;
        }

        if (!Stats::isCounts($colors, 4) || array_sum($colors) !== $pairs[3]) {
            return false;
        }

        return Stats::isCount($neighbours) && $neighbours <= $pairs[3];
    }
}
