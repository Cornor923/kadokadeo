<?php

namespace App\Achievements\Rules\Games\KanjisNightmare;

use App\Achievements\AchievementRule;
use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Stats;
use App\Enums\AchievementCategory;

abstract class KanjisNightmareRule implements AchievementRule
{
    public const OPT_200_PTS = 0;

    public const OPT_1000_PTS = 1;

    public const OPT_5000_PTS = 2;

    public const OPT_20_KUNAIS = 3;

    public const OPT_50_KUNAIS = 4;

    public const OPT_ADD_HOOK = 5;

    public const OPT_HP_UP = 6;

    public const OPT_INVINCIBILITY = 7;

    public const OPT_SLASH = 19;

    public const OPT_FLAME = 20;

    public const OPT_RESPAWN = 21;

    public const OPT_POINTS = 22;

    public const OPT_SHOES = 23;

    public const OPT_SUSHI = 24;

    public function __construct(private readonly string $gameKey = 'kanjisnightmare') {}

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
        $opts = data_get($event->stats, 'opt', []);
        $bads = data_get($event->stats, 'bads', []);
        $dif = data_get($event->stats, 'dif', 0);
        $gu = data_get($event->stats, 'gu', 0);

        return Stats::isList($opts, 26, is_int(...)) && Stats::isCounts($bads, 3) && is_int($dif) && Stats::isCount($gu);
    }
}
