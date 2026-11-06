<?php

namespace App\Achievements;

// The stats of a run are sent by the game: anything can be in them. A rule reads $stats[0] once validate() has seen a list
// (an object has other keys) of integers (a value above MAX can't be stored as a progress).
final class Stats
{
    // user_achievement_progress.current_value
    public const MAX = 2147483647;

    public static function isCount(mixed $value): bool
    {
        return is_int($value) && $value >= 0 && $value <= self::MAX;
    }

    /**
     * @param  ?int  $size  the number of items, any by default
     * @param  ?callable(mixed): bool  $item  what each item must pass
     */
    public static function isList(mixed $value, ?int $size = null, ?callable $item = null): bool
    {
        if (!is_array($value) || !array_is_list($value) || ($size !== null && count($value) !== $size)) {
            return false;
        }
        foreach ($value as $v) {
            if ($item !== null && !$item($v)) {
                return false;
            }
        }

        return true;
    }

    public static function isCounts(mixed $value, ?int $size = null): bool
    {
        return self::isList($value, $size, self::isCount(...));
    }

    // a list of lists of $rowSize counts
    public static function isRows(mixed $value, int $rowSize): bool
    {
        return self::isList($value, item: fn (mixed $row): bool => self::isCounts($row, $rowSize));
    }
}
