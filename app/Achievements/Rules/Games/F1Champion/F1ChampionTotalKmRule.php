<?php

namespace App\Achievements\Rules\Games\F1Champion;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class F1ChampionTotalKmRule extends F1ChampionRule
{
    private const DISTANCE_UNITS_PER_KM = 25;

    private const MAX_KM_PER_RUN = 900;

    public function achievementKey(): string
    {
        return 'total_km';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $remainingDistanceUnits = $progress->state['remaining_distance_units'] ?? 0;
        $distanceUnits = $remainingDistanceUnits + min(
            self::MAX_KM_PER_RUN * self::DISTANCE_UNITS_PER_KM,
            data_get($event->stats, 'n', 0),
        );
        $km = intdiv($distanceUnits, self::DISTANCE_UNITS_PER_KM);

        return AchievementRuleResult::increment($progress->current_value, $km, [
            'remaining_distance_units' => $distanceUnits % self::DISTANCE_UNITS_PER_KM,
        ]);
    }
}
