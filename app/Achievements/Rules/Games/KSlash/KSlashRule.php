<?php

namespace App\Achievements\Rules\Games\KSlash;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\GameRule;
use App\Achievements\Stats;

abstract class KSlashRule extends GameRule
{
    protected const GAME = 'kslash';

    public function validate(GameRunCompleted $event): bool
    {
        $opts = data_get($event->stats, 'opt', []);
        $bads = data_get($event->stats, 'bads', []);
        $kills = data_get($event->stats, 'k', []);
        $softKills = data_get($event->stats, 'sk', []);
        $dif = data_get($event->stats, 'dif', 0);
        $respawn = data_get($event->stats, 'respawn', 0);
        $supak = data_get($event->stats, 'supak', 0);
        // -1: no shuriken in the run
        $firstStarScore = data_get($event->stats, 'fssc', -1);
        $maxs = data_get($event->stats, 'maxs', 0);
        $maxb = data_get($event->stats, 'maxb', 0);

        if (!Stats::isCounts($bads, 5) || !Stats::isCounts($kills, 5) || !Stats::isCounts($softKills, 5) || !Stats::isList($opts, 10, is_int(...))) {
            return false;
        }

        foreach ([$respawn, $supak, $maxs, $maxb] as $count) {
            if (!Stats::isCount($count)) {
                return false;
            }
        }

        if ($respawn > $opts[7]) {
            return false;
        }

        if ($maxb >> 3 !== 0) {
            return false;
        }

        foreach ($bads as $i => $bad) {
            if ($kills[$i] > $bad || $softKills[$i] > $bad) {
                return false;
            }
        }

        if ($supak > array_sum($kills)) {
            return false;
        }

        if (!is_int($firstStarScore) || $firstStarScore < -1 || $firstStarScore > $event->run->score) {
            return false;
        }

        return $maxs <= 200 && is_int($dif);
    }
}
