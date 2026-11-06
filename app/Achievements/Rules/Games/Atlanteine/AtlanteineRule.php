<?php

namespace App\Achievements\Rules\Games\Atlanteine;

use App\Achievements\AchievementRule;
use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Stats;
use App\Enums\AchievementCategory;

abstract class AtlanteineRule implements AchievementRule
{
    public function __construct(private readonly string $gameKey = 'atlanteine') {}

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
        $levels = data_get($event->stats, 's', []);
        if (!Stats::isRows($levels, 8)) {
            return false;
        }

        foreach ($levels as [, $ghostsInLevel, $boxesMoved, $ghostsKilledBySelf, $ghostsKilledByBlock, $timesKilledByWater, , $hasPushedInLevel]) {
            if ($boxesMoved > $timesKilledByWater + $ghostsKilledBySelf + 1 || $ghostsKilledBySelf + $ghostsKilledByBlock > $ghostsInLevel) {
                return false;
            }
            if ($hasPushedInLevel > 1) {
                return false;
            }
        }

        return true;
    }

    protected function levels(GameRunCompleted $event): array
    {
        return data_get($event->stats, 's', []);
    }

    protected function bestProgress(int $currentValue, int $value): AchievementRuleResult
    {
        if ($value <= $currentValue) {
            return AchievementRuleResult::unchanged($currentValue);
        }

        return AchievementRuleResult::setProgress($value);
    }
}
