<?php

namespace App\Achievements;

class AchievementRuleResult
{
    private function __construct(
        public readonly bool $changed,
        public readonly int $progress,
        public readonly ?array $state = null,
    ) {}

    public static function unchanged(int $progress): self
    {
        return new self(false, $progress);
    }

    public static function setProgress(int $progress, ?array $state = null): self
    {
        return new self(true, min(Stats::MAX, max(0, $progress)), $state);
    }

    public static function increment(int $currentValue, int $amount = 1, ?array $state = null): self
    {
        return self::setProgress($currentValue + min($amount, Stats::MAX), $state);
    }
}
