<?php

namespace App\Achievements\Rules\Games\Starfang;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\GameRule;
use App\Achievements\Stats;

abstract class StarfangRule extends GameRule
{
    protected const GAME = 'starfang';

    public function validate(GameRunCompleted $event): bool
    {
        $bonuses = data_get($event->stats, 'b', []);
        $killsByBonus = data_get($event->stats, 'kb', []);
        $levels = data_get($event->stats, 'l', []);

        return Stats::isList($bonuses, item: is_int(...)) && Stats::isCounts($killsByBonus, 11) && Stats::isRows($levels, 7);
    }

    protected function completedLevels(array $levels): array
    {
        if (count($levels) === 0) {
            return [];
        }

        return array_slice($levels, 0, -1);
    }
}
