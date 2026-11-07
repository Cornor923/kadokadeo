<?php

namespace App\Achievements\Rules\Games\ZipZap;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\GameRule;
use App\Achievements\Stats;

abstract class ZipZapRule extends GameRule
{
    protected const GAME = 'zipzap';

    public function validate(GameRunCompleted $event): bool
    {
        $combo = data_get($event->stats, 'c', []);
        $clics = data_get($event->stats, 'm', 0);
        $perAction = data_get($event->stats, 'pa', []);
        $blackBalloons = data_get($event->stats, 'bb', []);

        if (!Stats::isCount($clics) || !Stats::isCounts($combo, 5) || !Stats::isRows($perAction, 6) || count($perAction) !== $clics || !Stats::isRows($blackBalloons, 2)) {
            return false;
        }

        $perActionTotals = [0, 0, 0, 0, 0];
        $blackPops = 0;
        foreach ($perAction as $action) {
            for ($i = 0; $i < 5; $i++) {
                $perActionTotals[$i] += $action[$i];
            }

            $blackPops += $action[5];
        }

        return $perActionTotals === $combo && $blackPops <= 1 && $blackPops <= count($blackBalloons);
    }
}
