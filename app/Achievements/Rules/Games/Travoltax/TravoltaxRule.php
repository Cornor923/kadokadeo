<?php

namespace App\Achievements\Rules\Games\Travoltax;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\GameRule;
use App\Achievements\Stats;

abstract class TravoltaxRule extends GameRule
{
    protected const GAME = 'travoltax';

    public function validate(GameRunCompleted $event): bool
    {
        $linesDestroyed = data_get($event->stats, '_l', []);
        $bonuses = data_get($event->stats, '_g', []);
        $opts = data_get($event->stats, '_o', []);
        $contracts = data_get($event->stats, '_c');
        $survivalFrames = data_get($event->stats, '_t');
        $clearCount = data_get($event->stats, '_cc');

        return is_array($bonuses) && count($bonuses) === 3
            && is_array($opts)
            && Stats::isCounts($linesDestroyed)
            && Stats::isList($contracts, item: fn (mixed $contract): bool => Stats::isCount($contract) && $contract <= 17)
            && Stats::isCount($survivalFrames)
            && Stats::isCount($clearCount);
    }
}
