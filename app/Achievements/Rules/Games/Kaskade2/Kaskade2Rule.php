<?php

namespace App\Achievements\Rules\Games\Kaskade2;

use App\Achievements\AchievementRule;
use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Stats;
use App\Enums\AchievementCategory;

abstract class Kaskade2Rule implements AchievementRule
{
    public function __construct(private readonly string $gameKey = 'kaskade2') {}

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
        $pops = data_get($event->stats, 'g', []);
        $time = data_get($event->stats, 't', []);
        $clicks = data_get($event->stats, 'd', []);

        return Stats::isList($pops, 20, fn (mixed $pop): bool => Stats::isCount($pop) && $pop <= 64)
            && is_array($time) && count($time) === 20
            && Stats::isList($clicks, 20, fn (mixed $click): bool => Stats::isCounts($click, 3) && $click[0] <= 7 && $click[1] <= 7 && $click[2] <= 2);
    }

    protected function clicks(GameRunCompleted $event): array
    {
        return data_get($event->stats, 'd', []);
    }
}
