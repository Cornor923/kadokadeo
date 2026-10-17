<?php

namespace Tests\Feature;

use App\Models\Clan;
use App\Models\DailyGame;
use App\Models\Game;
use App\Models\Period;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

// the daily game is played once a day: asked again the same day, it is refused with a message shown in the game. Outside
// the production it can be played again (0fe63e9c, the staging).
class DailyGameOnceTest extends TestCase
{
    use RefreshDatabase;

    private Game $game;

    private DailyGame $daily;

    protected function setUp(): void
    {
        parent::setUp();
        Period::factory()->create(['start_at' => now()->subDay()->startOfDay(), 'end_at' => now()->addDays(12)->endOfDay()]);
        $this->game = Game::factory()->create();
        $this->daily = DailyGame::create([
            'day' => today()->toDateString(),
            'game_id' => $this->game->id,
            'seed' => 'daily-seed',
            'contract_score' => 1234,
            'contract_points' => 50,
        ]);
    }

    private function beginDaily()
    {
        return $this->postJson("/api/runs/games/{$this->game->id}", ['daily' => true])->assertSuccessful();
    }

    public function test_the_daily_game_is_played_once_a_day_in_production(): void
    {
        $this->app['env'] = 'production';
        Sanctum::actingAs(User::factory()->create());

        $this->beginDaily()
            ->assertJsonPath('data.shared_seed', true)
            ->assertJsonPath('data.seed', 'daily-seed')
            ->assertJsonPath('data.contract_score', 1234)
            ->assertJsonPath('data.contract_points', 50);

        // again the same day: refused
        $this->postJson("/api/runs/games/{$this->game->id}", ['daily' => true])
            ->assertForbidden()
            ->assertJsonPath('message', 'Vous avez déjà joué la partie du jour : revenez demain !');
        $this->assertSame(1, $this->daily->runs()->count());
        $this->assertSame(1, $this->game->runs()->count());

        // the next day: the daily game of that day can be played
        $this->travel(1)->days();
        DailyGame::create(['day' => today()->toDateString(), 'game_id' => $this->game->id, 'seed' => 'next-seed', 'contract_score' => 10, 'contract_points' => 5]);
        $this->beginDaily()->assertJsonPath('data.shared_seed', true)->assertJsonPath('data.seed', 'next-seed');
    }

    // each player plays it once
    public function test_another_player_plays_the_daily_game_after_the_first_one(): void
    {
        $this->app['env'] = 'production';

        Sanctum::actingAs(User::factory()->create());
        $this->beginDaily()->assertJsonPath('data.shared_seed', true);
        Sanctum::actingAs(User::factory()->create());
        $this->beginDaily()->assertJsonPath('data.shared_seed', true);
        $this->assertSame(2, $this->daily->runs()->count());
    }

    // a clan run asked on the game of the day does not make the daily game playable again, nor takes it
    public function test_a_clan_run_does_not_change_the_daily_game(): void
    {
        $this->app['env'] = 'production';
        $player = User::factory()->create();
        Clan::factory()->withLeader($player)->create();
        $defender = Clan::factory()->withLeader()->create();
        Sanctum::actingAs($player);

        $this->beginDaily()->assertJsonPath('data.shared_seed', true);
        $this->postJson("/api/clans/{$defender->id}/attacks", ['game_id' => $this->game->id])->assertCreated();
        $this->postJson("/api/runs/games/{$this->game->id}", ['daily' => true])->assertForbidden();
        $this->assertSame(1, $this->daily->runs()->count());
        $this->assertDatabaseHas('clan_actions', ['user_id' => $player->id, 'run_id' => null]);
    }

    // another game asked as the daily game (a page opened the day before...): refused, in the staging too
    public function test_a_game_that_is_not_the_daily_game_is_refused(): void
    {
        $this->app['env'] = 'staging';
        Sanctum::actingAs(User::factory()->create());
        $other = Game::factory()->create();

        $this->postJson("/api/runs/games/{$other->id}", ['daily' => true])
            ->assertForbidden()
            ->assertJsonPath('message', 'Ce jeu n\'est pas la partie du jour.');
        $this->assertSame(0, $other->runs()->count());
    }

    public function test_the_daily_game_can_be_played_again_outside_the_production(): void
    {
        $this->app['env'] = 'staging';
        Sanctum::actingAs(User::factory()->create());

        $this->beginDaily()->assertJsonPath('data.shared_seed', true);
        $this->beginDaily()->assertJsonPath('data.shared_seed', true);
    }
}
