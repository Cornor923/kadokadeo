<?php

namespace App\Achievements\Rules\Games\MiniRace;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\GameRule;
use App\Achievements\Stats;

abstract class MiniRaceRule extends GameRule
{
    protected const GAME = 'minirace';

    // the cars overtaken by pid (1 green, 2 blue, 3 pink)
    protected const PINK = 2;

    // a race is 6 laps; a lap of 25 seconds ends the game (minirace.Game.updateChrono)
    private const LAPS = 6;

    private const LAP_MAX_MS = 24999;

    // _ot: each lap [seconds, thousandths(, 1 furious / 2 fast)], _lp: each lap [off track, perfect], _pa: the cars
    // overtaken by pid, _x: 1 when the car exploded
    public function validate(GameRunCompleted $event): bool
    {
        $times = data_get($event->stats, '_ot');
        $laps = data_get($event->stats, '_lp');
        $overtaken = data_get($event->stats, '_pa');
        $exploded = data_get($event->stats, '_x');

        $isTime = fn (mixed $lap): bool => Stats::isList($lap) && in_array(count($lap), [2, 3], true)
            && Stats::isCount($lap[0]) && Stats::isCount($lap[1]) && $lap[1] <= 999
            && $lap[0] * 1000 + $lap[1] <= self::LAP_MAX_MS
            && (count($lap) === 2 || in_array($lap[2], [1, 2], true));
        if (!Stats::isList($times, item: $isTime) || count($times) > self::LAPS) {
            return false;
        }

        // (a perfect lap is never off track)
        $isLap = fn (mixed $lap): bool => Stats::isCounts($lap, 2) && $lap[0] <= 1 && $lap[1] <= 1 && !($lap[0] === 1 && $lap[1] === 1);
        if (!Stats::isList($laps, count($times), $isLap)) {
            return false;
        }

        return Stats::isCounts($overtaken, 3) && in_array($exploded, [0, 1], true);
    }

    /**
     * The time of each lap, in thousandths of a second.
     *
     * @return list<int>
     */
    protected function lapTimes(GameRunCompleted $event): array
    {
        return array_map(fn (array $lap): int => $lap[0] * 1000 + $lap[1], data_get($event->stats, '_ot'));
    }
}
