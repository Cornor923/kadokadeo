<?php

namespace Database\Factories;

use App\Models\League;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<League>
 */
class LeagueFactory extends Factory
{
    public function definition(): array
    {
        return [
            'level' => $this->faker->numberBetween(1, 5),
            'name' => $this->faker->word(),
        ];
    }
}
