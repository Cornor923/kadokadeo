<?php

namespace Tests\Feature;

use App\Models\Game;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PersonalRecordsTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_records_include_current_period_score_and_all_time_record(): void
    {
        $user = User::factory()->create();
        $game = Game::factory()->create(['name' => 'Personal Record Game']);
        $currentPeriod = Period::factory()->create([
            'start_at' => now()->subDays(2),
            'end_at' => now()->addDays(11),
        ]);
        $previousPeriod = Period::factory()->create([
            'start_at' => now()->subDays(30),
            'end_at' => now()->subDays(17),
        ]);

        Run::factory()->for($currentPeriod)->for($game)->for($user)->create(['score' => 800]);
        Run::factory()->for($previousPeriod)->for($game)->for($user)->create(['score' => 1000]);

        $this->actingAs($user, 'sanctum')
            ->getJson("/api/users/{$user->etwin_id}/records")
            ->assertOk()
            ->assertJson([
                [
                    'game' => [
                        'id' => $game->id,
                        'name' => 'Personal Record Game',
                        'stars' => [10, 20, 30, 40],
                    ],
                    'score' => 1000,
                    'current_score' => 800,
                ],
            ])
            ->assertJsonPath('0.league.level', 1);
    }

    public function test_the_records_of_another_player_are_theirs(): void
    {
        $viewer = User::factory()->create();
        $player = User::factory()->create();
        $game = Game::factory()->create();
        $period = Period::factory()->create([
            'start_at' => now()->subDays(2),
            'end_at' => now()->addDays(11),
        ]);

        Run::factory()->for($period)->for($game)->for($viewer)->create(['score' => 5000]);
        Run::factory()->for($period)->for($game)->for($player)->create(['score' => 300]);

        $this->actingAs($viewer, 'sanctum')
            ->getJson("/api/users/{$player->etwin_id}/records")
            ->assertOk()
            ->assertJsonPath('0.game.id', $game->id)
            ->assertJsonPath('0.score', 300)
            ->assertJsonPath('0.current_score', 300);
    }
}
