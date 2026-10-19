<?php

namespace Database\Factories;

use App\Models\Run;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\RunComment>
 */
class RunCommentFactory extends Factory
{
    public function definition(): array
    {
        return [
            'run_id' => Run::factory(),
            'user_id' => User::factory(),
            'frame' => fake()->numberBetween(0, 3000),
            'content' => fake()->sentence(),
        ];
    }
}
