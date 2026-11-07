<?php

namespace App\Achievements\Rules\Games\PiouPiou;

use App\Achievements\AchievementRule;
use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Stats;
use App\Enums\AchievementCategory;

abstract class PiouPiouRule implements AchievementRule
{
    public function __construct(private readonly string $gameKey = 'pioupiou') {}

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
        $bubbles = data_get($event->stats, 'b', []);
        $height = data_get($event->stats, 'l', 0);
        // -1: no bubble in the run
        $firstBubbleLevel = data_get($event->stats, 'fbl', -1);
        $fallingBubbles = data_get($event->stats, 'fb', []);
        $bubblePopped = data_get($event->stats, 'bp', []);
        $climbHeight = data_get($event->stats, 'ch', 0);

        return Stats::isCount($height)
            && is_int($firstBubbleLevel) && $firstBubbleLevel >= -1 && $firstBubbleLevel <= $height
            && Stats::isCount($climbHeight)
            && Stats::isCounts($bubbles, 3)
            && Stats::isCounts($fallingBubbles, 3)
            && Stats::isCounts($bubblePopped, 3);
    }
}
