<?php

namespace App\Achievements\Rules\Games\KillBulle;

use App\Achievements\AchievementRule;
use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Stats;
use App\Enums\AchievementCategory;

abstract class KillBulleRule implements AchievementRule
{
    public function __construct(private readonly string $gameKey = 'killbulle') {}

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
        $pops = data_get($event->stats, 's', 0);
        $poppedSizes = data_get($event->stats, 'p', []);
        $bonusPops = data_get($event->stats, 'bp', []);

        if (!Stats::isCount($pops) || !Stats::isCounts($bonuses, 4) || !Stats::isList($bonusPops, 4, fn (mixed $popsByPickup): bool => Stats::isCounts($popsByPickup))) {
            return false;
        }

        if (!Stats::isList($poppedSizes, $pops, fn (mixed $size): bool => in_array($size, [12, 25, 50, 100, 150], true))) {
            return false;
        }

        for ($bonusId = 0; $bonusId < 3; $bonusId++) {
            if (count($bonusPops[$bonusId]) !== $bonuses[$bonusId]) {
                return false;
            }
        }

        return count($bonusPops[3]) === 0;
    }
}
