<?php

namespace App\Achievements\Rules\Games\Tubulo;

use App\Achievements\AchievementRule;
use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Stats;
use App\Enums\AchievementCategory;

abstract class TubuloRule implements AchievementRule
{
    public function __construct(private readonly string $gameKey = 'tubulo') {}

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
        $completedLevels = data_get($event->stats, '_e', []);
        $resets = data_get($event->stats, '_r', []);
        $levelColors = data_get($event->stats, '_l', []);
        $levelChronos = data_get($event->stats, '_cl', []);

        if (!Stats::isList($completedLevels) || !Stats::isCounts($resets) || !Stats::isRows($levelColors, 3) || !Stats::isCounts($levelChronos)) {
            return false;
        }

        if (count($levelColors) !== count($completedLevels) + 1 || count($levelChronos) !== count($completedLevels)) {
            return false;
        }

        foreach ($resets as $level) {
            if ($level > count($completedLevels) + 1) {
                return false;
            }
        }

        foreach ($levelColors as $colors) {
            if (array_sum($colors) !== 49) {
                return false;
            }
        }

        foreach ($levelChronos as $chrono) {
            if ($chrono > 3000) {
                return false;
            }
        }

        return true;
    }

    protected function completedLevels(GameRunCompleted $event): array
    {
        return data_get($event->stats, '_e', []);
    }

    protected function resets(GameRunCompleted $event): array
    {
        return data_get($event->stats, '_r', []);
    }

    protected function levelColors(GameRunCompleted $event): array
    {
        return data_get($event->stats, '_l', []);
    }

    protected function levelChronos(GameRunCompleted $event): array
    {
        return data_get($event->stats, '_cl', []);
    }

    protected function bestProgress(int $currentValue, int $value): AchievementRuleResult
    {
        if ($value <= $currentValue) {
            return AchievementRuleResult::unchanged($currentValue);
        }

        return AchievementRuleResult::setProgress($value);
    }
}
