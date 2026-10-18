<?php

namespace Database\Factories;

use App\Models\Clan;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\Clan>
 */
class ClanFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => fake()->unique()->lexify('Clan ????'),
            'description' => fake()->sentence(),
            'is_recruiting' => true,
        ];
    }

    // a clan led by a (new) player, member of it
    public function withLeader(?User $leader = null): static
    {
        return $this->afterCreating(function (Clan $clan) use ($leader) {
            $leader ??= User::factory()->create();
            $clan->members()->create(['user_id' => $leader->id]);
            $clan->update(['leader_id' => $leader->id]);
        });
    }
}
