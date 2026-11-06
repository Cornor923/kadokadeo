<?php

namespace App\Achievements\Rules\Games\ChocoMouche;

use App\Achievements\AchievementRule;
use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Stats;
use App\Enums\AchievementCategory;

abstract class ChocoMoucheRule implements AchievementRule
{
    public function __construct(private readonly string $gameKey = 'chocomouche') {}

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
        $discoveries = data_get($event->stats, 'd', []);
        $clicks = data_get($event->stats, 'c', []);
        $points = data_get($event->stats, 'p', []);
        $times = data_get($event->stats, 't', []);

        $isDiscovery = fn (mixed $discovery): bool => is_int($discovery) && $discovery >= -2 && $discovery <= 8;
        if (!Stats::isList($discoveries, item: fn (mixed $level): bool => Stats::isList($level, item: $isDiscovery))) {
            return false;
        }
        if (!Stats::isCounts($clicks) || !Stats::isCounts($points) || !Stats::isCounts($times)) {
            return false;
        }

        if (count($discoveries) !== count($clicks) || count($points) !== count($times) || count($discoveries) !== count($points) + 1) {
            return false;
        }

        // a finished level has clicks
        return !in_array(0, array_slice($clicks, 0, count($points)), true);
    }

    protected function bestProgress(int $currentValue, int $value): AchievementRuleResult
    {
        if ($value <= $currentValue) {
            return AchievementRuleResult::unchanged($currentValue);
        }

        return AchievementRuleResult::setProgress($value);
    }
}
