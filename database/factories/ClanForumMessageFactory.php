<?php

namespace Database\Factories;

use App\Models\ClanForumTopic;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\ClanForumMessage>
 */
class ClanForumMessageFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'topic_id' => ClanForumTopic::factory(),
            'content' => fake()->paragraph(),
        ];
    }
}
