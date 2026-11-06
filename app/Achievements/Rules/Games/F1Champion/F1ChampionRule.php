<?php

namespace App\Achievements\Rules\Games\F1Champion;

use App\Achievements\AchievementRule;
use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Stats;
use App\Enums\AchievementCategory;

abstract class F1ChampionRule implements AchievementRule
{
    public function __construct(private readonly string $gameKey = 'f1champion') {}

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
        $km = data_get($event->stats, 'n', 0);
        $outs = data_get($event->stats, 'o');
        $maxKmWithoutOut = data_get($event->stats, 'm');
        $speedOver230Frames = data_get($event->stats, 'so');
        $life = data_get($event->stats, 'l');

        return Stats::isCount($km)
            && Stats::isCounts($bonuses, 5)
            && Stats::isCount($outs)
            && Stats::isCount($maxKmWithoutOut)
            && Stats::isCount($speedOver230Frames)
            && Stats::isList($life, item: fn (mixed $percentage): bool => Stats::isCount($percentage) && $percentage <= 100);
    }
}
