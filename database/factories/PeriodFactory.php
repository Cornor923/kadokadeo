<?php

namespace Database\Factories;

use App\Models\Period;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Period>
 */
class PeriodFactory extends Factory
{
    public function definition(): array
    {
        $start = now()->startOfDay();

        return [
            'start_at' => $start,
            'end_at' => $start->clone()->addDays(Period::DAYS_PER_PERIOD)->endOfDay(),
        ];
    }
}
