<?php

namespace App\Achievements\Rules\Games\Tubulo;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\GameRule;
use App\Achievements\Stats;

abstract class TubuloRule extends GameRule
{
    protected const GAME = 'tubulo';

    public function validate(GameRunCompleted $event): bool
    {
        $completedLevels = data_get($event->stats, '_e', []);
        $resets = data_get($event->stats, '_r', []);
        $levelColors = data_get($event->stats, '_l', []);
        $levelChronos = data_get($event->stats, '_cl', []);

        if (!Stats::isList($completedLevels) || !Stats::isCounts($resets) || !Stats::isRows($levelColors, 3) || !Stats::isCounts($levelChronos)) {
            return false;
        }

        // (the colors of the level being played, missing when its reset filled the chrono: the game ends then)
        if (!in_array(count($levelColors) - count($completedLevels), [0, 1], true) || count($levelChronos) !== count($completedLevels)) {
            return false;
        }

        foreach ($resets as $level) {
            if ($level > count($completedLevels) + 1) {
                return false;
            }
        }

        foreach ($levelColors as $colors) {
            if (array_sum($colors) !== 49) {
                return false;
            }
        }

        foreach ($levelChronos as $chrono) {
            if ($chrono > 3000) {
                return false;
            }
        }

        return true;
    }

    protected function completedLevels(GameRunCompleted $event): array
    {
        return data_get($event->stats, '_e', []);
    }

    protected function resets(GameRunCompleted $event): array
    {
        return data_get($event->stats, '_r', []);
    }

    protected function levelColors(GameRunCompleted $event): array
    {
        return data_get($event->stats, '_l', []);
    }

    protected function levelChronos(GameRunCompleted $event): array
    {
        return data_get($event->stats, '_cl', []);
    }
}
