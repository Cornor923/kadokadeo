<?php

namespace App\Achievements\Rules\Games\Magmax;

use App\Achievements\AchievementRule;
use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Enums\AchievementCategory;

abstract class MagmaxRule implements AchievementRule
{
    public function __construct(private readonly string $gameKey = 'magmax') {}

    public function category(): AchievementCategory
    {
        return AchievementCategory::GAME;
    }

    public function gameKey(): ?string
    {
        return $this->gameKey;
    }

    public function supports(object $event): bool
    {
        return $event instanceof GameRunCompleted && $event->gameKey() === $this->gameKey;
    }

    // g: monsters generated per type (0 bomb, 1 flower, 2 turret), k: killed per type, c: combos per level (3: Magmax),
    // b: bonuses picked up per type (0-2 gems, 3 speed, 4 double fire), seq: bomb, flower, turret killed in a row in one
    // combo, dual: special bonuses picked up while the other one was active
    public function validate(GameRunCompleted $event): bool
    {
        $generated = data_get($event->stats, 'g');
        $kills = data_get($event->stats, 'k');
        $combos = data_get($event->stats, 'c');
        $bonuses = data_get($event->stats, 'b');
        $seq = data_get($event->stats, 'seq');
        $dual = data_get($event->stats, 'dual');

        if (!$this->isCounterList($generated, 3) || !$this->isCounterList($kills, 3) || !$this->isCounterList($combos, 4) || !$this->isCounterList($bonuses, 6)) {
            return false;
        }

        if (!is_int($seq) || $seq < 0 || !is_int($dual) || $dual < 0) {
            return false;
        }

        foreach ($kills as $i => $kill) {
            if ($kill > $generated[$i]) {
                return false;
            }
        }

        // one bonus dropped per kill
        if (array_sum($bonuses) > array_sum($kills)) {
            return false;
        }

        if ($seq > $kills[2]) {
            return false;
        }

        return $dual <= $bonuses[3] + $bonuses[4];
    }

    protected function bestProgress(int $currentValue, int $value): AchievementRuleResult
    {
        if ($value <= $currentValue) {
            return AchievementRuleResult::unchanged($currentValue);
        }

        return AchievementRuleResult::setProgress($value);
    }

    private function isCounterList(mixed $value, int $size): bool
    {
        if (!is_array($value) || !array_is_list($value) || count($value) !== $size) {
            return false;
        }

        foreach ($value as $count) {
            if (!is_int($count) || $count < 0) {
                return false;
            }
        }

        return true;
    }
}
