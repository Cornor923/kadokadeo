<?php

namespace App\Achievements\Rules\Games\TiananMan;

use App\Achievements\AchievementRule;
use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Stats;
use App\Enums\AchievementCategory;

abstract class TiananManRule implements AchievementRule
{
    public function __construct(private readonly string $gameKey = 'tiananman') {}

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
        $followersCollected = data_get($event->stats, 'fc', []);
        $vehiclesDestroyed = data_get($event->stats, 'vd', []);
        $fevers = data_get($event->stats, 'f', []);
        $followersLost = data_get($event->stats, 'fl', []);
        $lastFollowerScore = data_get($event->stats, 'lfsc', 0);

        if (!Stats::isCounts($vehiclesDestroyed, 5) || !Stats::isCounts($fevers) || !Stats::isCounts($followersLost) || !Stats::isCount($lastFollowerScore)) {
            return false;
        }

        if (count($followersLost) > 180 || count($followersLost) <= 0) {
            return false;
        }

        if (!Stats::isList($followersCollected, item: fn (mixed $follower): bool => Stats::isList($follower, 3, is_int(...)) && in_array($follower[2], [0, 1], true))) {
            return false;
        }

        $feverStreaks = 0;
        $wasInFever = false;
        foreach ($followersCollected as [, , $collectedDuringFever]) {
            if ($collectedDuringFever === 1 && !$wasInFever) {
                $feverStreaks++;
            }

            $wasInFever = $collectedDuringFever === 1;
        }

        return $feverStreaks <= count($fevers);
    }
}
