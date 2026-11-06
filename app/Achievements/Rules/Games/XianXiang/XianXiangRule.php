<?php

namespace App\Achievements\Rules\Games\XianXiang;

use App\Achievements\AchievementRule;
use App\Achievements\Events\GameRunCompleted;
use App\Enums\AchievementCategory;

abstract class XianXiangRule implements AchievementRule
{
    // the 42 cards of the board: a game only ends once they are all gone
    protected const PAIRS = 21;

    public function __construct(private readonly string $gameKey = 'xianxiang') {}

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
        // the pairs by attributes in common (3: the perfect pairs)
        $pairs = data_get($event->stats, 'c');
        // the perfect pairs by color
        $colors = data_get($event->stats, 'p');
        // the perfect pairs on neighbouring cells
        $neighbours = data_get($event->stats, 'n');

        if (!$this->isCountList($pairs) || array_sum($pairs) !== self::PAIRS) {
            return false;
        }

        if (!$this->isCountList($colors) || array_sum($colors) !== $pairs[3]) {
            return false;
        }

        return is_int($neighbours) && $neighbours >= 0 && $neighbours <= $pairs[3];
    }

    private function isCountList(mixed $counts): bool
    {
        if (!is_array($counts) || array_keys($counts) !== [0, 1, 2, 3]) {
            return false;
        }

        foreach ($counts as $count) {
            if (!is_int($count) || $count < 0) {
                return false;
            }
        }

        return true;
    }
}
