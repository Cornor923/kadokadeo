<?php

namespace Database\Factories;

use App\Models\Category;
use App\Models\Game;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Game>
 */
class GameFactory extends Factory
{
    public function definition(): array
    {
        return [
            'name' => fake()->unique()->word(),
            'description' => fake()->sentence(),
            'category_id' => Category::factory(),
            'stars' => [10, 20, 30, 40],
            'is_active' => true,
            'is_arkadeo' => false,
        ];
    }
}
