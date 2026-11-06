<?php

namespace App\Achievements\Rules\Games\ZipZap;

use App\Achievements\AchievementRule;
use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Stats;
use App\Enums\AchievementCategory;

abstract class ZipZapRule implements AchievementRule
{
    public function __construct(private readonly string $gameKey = 'zipzap') {}

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
        $combo = data_get($event->stats, 'c', []);
        $clics = data_get($event->stats, 'm', 0);
        $perAction = data_get($event->stats, 'pa', []);
        $blackBalloons = data_get($event->stats, 'bb', []);

        if (!Stats::isCount($clics) || !Stats::isCounts($combo, 5) || !Stats::isRows($perAction, 6) || count($perAction) !== $clics || !Stats::isRows($blackBalloons, 2)) {
            return false;
        }

        $perActionTotals = [0, 0, 0, 0, 0];
        $blackPops = 0;
        foreach ($perAction as $action) {
            for ($i = 0; $i < 5; $i++) {
                $perActionTotals[$i] += $action[$i];
            }

            $blackPops += $action[5];
        }

        return $perActionTotals === $combo && $blackPops <= 1 && $blackPops <= count($blackBalloons);
    }
}
