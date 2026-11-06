<?php

namespace App\Achievements\Rules\Games\Starfang;

use App\Achievements\AchievementRule;
use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Stats;
use App\Enums\AchievementCategory;

abstract class StarfangRule implements AchievementRule
{
    public function __construct(private readonly string $gameKey = 'starfang') {}

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
