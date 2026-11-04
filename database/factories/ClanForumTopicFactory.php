<?php

namespace Database\Factories;

use App\Models\Clan;
use App\Models\ClanForumTopic;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ClanForumTopic>
 */
class ClanForumTopicFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'clan_id' => Clan::factory(),
            'title' => fake()->sentence(4),
            'last_message_at' => now(),
        ];
    }
}
