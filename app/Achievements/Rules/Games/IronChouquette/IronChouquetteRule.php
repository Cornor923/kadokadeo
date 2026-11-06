<?php

namespace App\Achievements\Rules\Games\IronChouquette;

use App\Achievements\AchievementRule;
use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Stats;
use App\Enums\AchievementCategory;

abstract class IronChouquetteRule implements AchievementRule
{
    public function __construct(private readonly string $gameKey = 'ironchouquette') {}

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
        $kills = data_get($event->stats, 'k', []);
        $specialKills = data_get($event->stats, 'spk', []);
        $sacrificeKills = data_get($event->stats, 'sak', []);
        $maxEnemyShotCount = data_get($event->stats, 'mesc');
        $waves = data_get($event->stats, 'w', []);

        return Stats::isRows($bonuses, 2)
            && Stats::isRows($kills, 2)
            && Stats::isCounts($specialKills, 6)
            && Stats::isList($sacrificeKills, 6, fn (mixed $sacrifices): bool => Stats::isRows($sacrifices, 2))
            && Stats::isCount($maxEnemyShotCount)
            && Stats::isCounts($waves);
    }

    public function iterateThroughBonuses(GameRunCompleted $event, callable $callback): void
    {
        $bonuses = array_values(data_get($event->stats, 'b', []));

        $bonusSlots = [-1, -1, -1];
        foreach ($bonuses as $index => $bonus) {
            $removedBonus = -1;
            $b = $bonus[1];
            if ($b === 6) {
                $bonusSlots[] = -1;
            } elseif ($b > 99) {
                $nextBonus = $bonuses[$index + 1][1] ?? null;
                $isAutomaticReplacement = !in_array(-1, $bonusSlots, true)
                    && $nextBonus !== null
                    && $nextBonus < 100
                    && $nextBonus !== 6
                    && $bonusSlots[0] === $b - 100;

                // A full inventory removes its first slot before logging the new bonus.
                $pos = false;
                if ($isAutomaticReplacement) {
                    $pos = 0;
                } else {
                    for ($i = count($bonusSlots) - 1; $i >= 0; $i--) {
                        if ($bonusSlots[$i] !== -1) {
                            $pos = $i;
                            break;
                        }
                    }
                }
                if ($pos !== false) {
                    $removedBonus = array_splice($bonusSlots, $pos, 1)[0];
                    $bonusSlots[] = -1;
                }
            } else {
                // find the first slot with -1 and fill it or replace the first slot
                $pos = array_search(-1, $bonusSlots, true);
                if ($pos === false) {
                    $removedBonus = array_splice($bonusSlots, 0, 1)[0];
                    $bonusSlots[] = $b;
                } else {
                    $bonusSlots[$pos] = $b;
                }
            }
            $callback($bonusSlots, $b, $removedBonus);
        }
    }
}
