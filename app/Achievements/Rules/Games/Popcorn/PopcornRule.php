<?php

namespace App\Achievements\Rules\Games\Popcorn;

use App\Achievements\AchievementRule;
use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Enums\AchievementCategory;

abstract class PopcornRule implements AchievementRule
{
    public function __construct(private readonly string $gameKey = 'popcorn') {}

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
        $events = data_get($event->stats, 'e', []);
        $topReached = data_get($event->stats, 'tr', 0);
        $bossHitFrames = data_get($event->stats, 'bhf', []);

        if (!is_array($events) || !is_int($topReached) || $topReached < 0 || !is_array($bossHitFrames)) {
            return false;
        }

        $bossHits = 0;
        foreach ($events as $eventType) {
            if (!is_int($eventType) || $eventType < 0 || $eventType > 3) {
                return false;
            }

            if ($eventType === 2 && ++$bossHits > 7) {
                return false;
            }
        }

        if (count($bossHitFrames) !== $bossHits) {
            return false;
        }

        foreach ($bossHitFrames as $frame) {
            if (!is_int($frame) || $frame < 0) {
                return false;
            }
        }

        return true;
    }

    protected function events(GameRunCompleted $event): array
    {
        return data_get($event->stats, 'e', []);
    }

    protected function eventCount(GameRunCompleted $event, int $eventType): int
    {
        return count(array_filter($this->events($event), fn (int $event): bool => $event === $eventType));
    }

    protected function maxEventsBetween(GameRunCompleted $event, int $eventType, int $boundaryType): int
    {
        $max = 0;
        $current = null;

        foreach ($this->events($event) as $event) {
            if ($event === $boundaryType) {
                if ($current !== null) {
                    $max = max($max, $current);
                }

                $current = 0;
            } elseif ($event === $eventType && $current !== null) {
                $current++;
            }
        }

        return $max;
    }

    protected function bestProgress(int $currentValue, int $value): AchievementRuleResult
    {
        if ($value <= $currentValue) {
            return AchievementRuleResult::unchanged($currentValue);
        }

        return AchievementRuleResult::setProgress($value);
    }
}
