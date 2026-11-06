<?php

namespace App\Achievements\Rules\Games\Kanji;

use App\Achievements\AchievementRule;
use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Stats;
use App\Enums\AchievementCategory;

abstract class KanjiRule implements AchievementRule
{
    public function __construct(private readonly string $gameKey = 'kanji') {}

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
        $bonusCount = data_get($event->stats, 'n', 0);
        $bonuses = data_get($event->stats, 'b', []);
        $mobs = data_get($event->stats, 'm', []);
        $level = data_get($event->stats, 'l', 0);
        $tmod = data_get($event->stats, 't', 0);
        $kills = data_get($event->stats, 'k', 0);
        $killStreak = data_get($event->stats, 'ks', 0);
        $wallJumps = data_get($event->stats, 'wj', 0);
        $bonusStreak = data_get($event->stats, 'bs', 0);
        $bearAvoided = data_get($event->stats, 'ba', 0);
        $bearAvoidedShort = data_get($event->stats, 'bas', 0);
        $lastKillCount = data_get($event->stats, 'lk', 0);
        $firstKillScore = data_get($event->stats, 'fksc', -1);
        $flyStreak = data_get($event->stats, 'fs', 0);

        if (!Stats::isCounts($bonuses, 3) || !Stats::isCounts($mobs, 3)) {
            return false;
        }

        foreach ([$bonusCount, $kills, $killStreak, $wallJumps, $bonusStreak, $bearAvoided, $bearAvoidedShort, $lastKillCount, $flyStreak] as $count) {
            if (!Stats::isCount($count)) {
                return false;
            }
        }

        if ($kills > $mobs[0] || $killStreak > $mobs[0] || $lastKillCount > $mobs[0]) {
            return false;
        }

        if ($bearAvoided > $mobs[2] || $bearAvoidedShort > $mobs[2]) {
            return false;
        }

        if (!is_int($firstKillScore) || $firstKillScore < -1 || $firstKillScore > $event->run->score) {
            return false;
        }

        if (($flyStreak / 32) > $event->run->play_time_seconds) {
            return false;
        }

        return is_int($level) && is_int($tmod) && array_sum($bonuses) === $bonusCount;
    }
}
