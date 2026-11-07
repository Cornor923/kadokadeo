<?php

namespace App\Achievements\Rules\Games\Pioutch;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\GameRule;
use App\Achievements\Stats;

abstract class PioutchRule extends GameRule
{
    protected const GAME = 'pioutch';

    // the types of birds (pioutch.Game: 0 pink, 1 green, 2 violet, 3 orange: one more fury)
    protected const VIOLET = 2;

    // the game starts with 5 lives, a bird lost takes one: the game ends with the fifth
    private const LIVES = 5;

    // ... and 3 furies
    private const FURIES = 3;

    // c: birds shot, s: saved, l: lost, f: furies used, lt: lost by type, fs: the score at the first bird lost or the
    // first fury (-1: neither), mf: the most furies held at once
    public function validate(GameRunCompleted $event): bool
    {
        $shot = data_get($event->stats, 'c');
        $saved = data_get($event->stats, 's');
        $lost = data_get($event->stats, 'l');
        $furies = data_get($event->stats, 'f');
        $lostByType = data_get($event->stats, 'lt');
        $firstMistakeScore = data_get($event->stats, 'fs');
        $mostFuries = data_get($event->stats, 'mf');

        foreach ([$shot, $saved, $lost, $furies, $mostFuries] as $count) {
            if (!Stats::isCount($count)) {
                return false;
            }
        }

        if (!Stats::isCounts($lostByType, 4) || array_sum($lostByType) !== $lost) {
            return false;
        }

        // a bird shot is saved, lost, or still flying at the end
        if ($saved + $lost > $shot || $lost > self::LIVES || $mostFuries < self::FURIES) {
            return false;
        }

        if (!is_int($firstMistakeScore) || $firstMistakeScore < -1 || $firstMistakeScore > $event->run->score) {
            return false;
        }

        return ($firstMistakeScore === -1) === ($lost === 0 && $furies === 0);
    }
}
