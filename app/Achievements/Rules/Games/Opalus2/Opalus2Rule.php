<?php

namespace App\Achievements\Rules\Games\Opalus2;

use App\Achievements\AchievementRule;
use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Stats;
use App\Enums\AchievementCategory;

abstract class Opalus2Rule implements AchievementRule
{
    public function __construct(private readonly string $gameKey = 'opalus2') {}

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

    public function validate(GameRunCompleted $event): bool
    {
        $turns = data_get($event->stats, 'l', []);
        $fallenByColor = data_get($event->stats, 'f', []);
        $minMax = data_get($event->stats, 'mm', []);

        if (!Stats::isRows($turns, 3) || !Stats::isRows($fallenByColor, 7) || count($fallenByColor) !== count($turns)) {
            return false;
        }

        if (!Stats::isList($minMax, 4, fn (mixed $value): bool => Stats::isCount($value) && $value <= 14)) {
            return false;
        }

        $destroyedTotal = 0;
        $fallenTotal = 0;
        foreach ($turns as $index => [$colorId, $destroyed, $fallen]) {
            if ($colorId > 6 || array_sum($fallenByColor[$index]) !== $fallen) {
                return false;
            }

            $destroyedTotal += $destroyed;
            $fallenTotal += $fallen;
            if ($destroyedTotal > 225 || $fallenTotal > 225) {
                return false;
            }
        }

        return true;
    }

    protected function turns(GameRunCompleted $event): array
    {
        return data_get($event->stats, 'l', []);
    }

    protected function fallenByColor(GameRunCompleted $event): array
    {
        return data_get($event->stats, 'f', []);
    }

    protected function minMax(GameRunCompleted $event): array
    {
        return data_get($event->stats, 'mm', []);
    }
}
