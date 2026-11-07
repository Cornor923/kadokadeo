<?php

namespace App\Achievements\Rules\Games\F1Champion;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\GameRule;
use App\Achievements\Stats;

abstract class F1ChampionRule extends GameRule
{
    protected const GAME = 'f1champion';

    public function validate(GameRunCompleted $event): bool
    {
        $bonuses = data_get($event->stats, 'b', []);
        $km = data_get($event->stats, 'n', 0);
        $outs = data_get($event->stats, 'o');
        $maxKmWithoutOut = data_get($event->stats, 'm');
        $speedOver230Frames = data_get($event->stats, 'so');
        $life = data_get($event->stats, 'l');

        return Stats::isCount($km)
            && Stats::isCounts($bonuses, 5)
            && Stats::isCount($outs)
            && Stats::isCount($maxKmWithoutOut)
            && Stats::isCount($speedOver230Frames)
            && Stats::isList($life, item: fn (mixed $percentage): bool => Stats::isCount($percentage) && $percentage <= 100);
    }
}
