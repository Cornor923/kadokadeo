<?php

namespace Tests\Feature;

use App\Models\DailyGame;
use App\Models\Game;
use App\Models\Run;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

// the beginning of a run: on a game that can be opened, with a game of the day left
class RunBeginTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // (the bundle of "Testgame" only, GamePolicy::view)
        $this->app->usePublicPath(base_path('tests/Fixtures/game-builds/public'));
        config(['kado.games_per_day' => 100]);
    }

    private function game(array $attributes = []): Game
    {
        return Game::factory()->create(['name' => 'Testgame', ...$attributes]);
    }

    public function test_a_run_takes_a_game_of_the_day(): void
    {
        $user = User::factory()->create(['kado_games' => 1]);
        $game = $this->game();
        Sanctum::actingAs($user);

        $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful();
        $this->assertSame(0, $user->fresh()->kado_games);

        $this->postJson("/api/runs/games/{$game->id}")
            ->assertForbidden()
            ->assertJsonPath('message', 'Vous n\'avez plus de parties aujourd\'hui : revenez demain !');
        $this->assertSame(1, Run::count());
    }

    // two runs begun at once: the second one sees the player loaded before the first one took the last game
    public function test_the_last_game_is_taken_once_by_runs_begun_at_once(): void
    {
        $user = User::factory()->create(['kado_games' => 1]);
        $game = $this->game();
        Sanctum::actingAs($user);
        User::query()->whereKey($user->id)->update(['kado_games' => 0]);

        $this->postJson("/api/runs/games/{$game->id}")
            ->assertForbidden()
            ->assertJsonPath('message', 'Vous n\'avez plus de parties aujourd\'hui : revenez demain !');
        $this->assertSame(0, Run::count());
        $this->assertSame(0, $user->fresh()->kado_games);
    }

    public function test_the_runs_left_open_long_ago_no_longer_block_the_player(): void
    {
        config(['kado.runs.max_concurrency' => 2, 'kado.runs.open_minutes' => 120]);
        $user = User::factory()->create(['kado_games' => 10]);
        $game = $this->game();
        Sanctum::actingAs($user);
        // two tabs closed during a game, yesterday
        Run::factory()->count(2)->for($user)->for($game)->create(['score' => null, 'completed_at' => null, 'created_at' => now()->subDay()]);

        $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful();
        $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful();
        // two runs open now: the limit
        $this->postJson("/api/runs/games/{$game->id}")->assertForbidden();
    }

    public function test_unlimited_games_go_on_at_zero(): void
    {
        config(['kado.games_per_day' => -1]);
        $user = User::factory()->create(['kado_games' => 0]);
        $game = $this->game();
        Sanctum::actingAs($user);

        $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful();
        $this->assertSame(0, $user->fresh()->kado_games);
    }

    public function test_a_game_turned_off_or_without_its_bundle_is_not_played_nor_ranked(): void
    {
        Sanctum::actingAs(User::factory()->create(['kado_games' => 10]));
        $off = $this->game(['is_active' => false]);
        $noBundle = Game::factory()->create(['name' => 'Nobundle']);

        $this->postJson("/api/runs/games/{$off->id}")->assertForbidden();
        $this->postJson("/api/runs/games/{$noBundle->id}")->assertForbidden();
        $this->assertSame(0, Run::count());
        $this->getJson("/api/games/{$off->id}/ranking")->assertForbidden();
        $this->getJson("/api/games/{$noBundle->id}/ranking")->assertForbidden();

        $off->update(['is_active' => true]);
        $this->getJson("/api/games/{$off->id}/ranking")->assertOk();
    }

    // the ranking of a game is public
    public function test_the_ranking_of_a_game_is_seen_by_the_guests(): void
    {
        $this->getJson("/api/games/{$this->game()->id}/ranking")->assertOk();
    }

    // the daily game: its run is created with the daily game (GamePolicy::playDaily checks it); the seed is not given by
    // the page of the daily game, only to the game when its run begins
    public function test_the_daily_run_is_bound_to_the_daily_game_and_its_seed_is_given_when_it_begins(): void
    {
        $game = $this->game();
        $daily = DailyGame::create(['day' => today()->toDateString(), 'game_id' => $game->id, 'seed' => 'daily-seed', 'contract_score' => 10, 'contract_points' => 5]);
        Sanctum::actingAs(User::factory()->create(['kado_games' => 10]));

        $this->getJson('/api/daily/game')
            ->assertOk()
            ->assertJsonPath('dailyGame.id', $daily->id)
            ->assertJsonPath('dailyGame.contract_score', 10)
            ->assertJsonMissingPath('dailyGame.seed');

        $this->postJson("/api/runs/games/{$game->id}", ['daily' => true])
            ->assertSuccessful()
            ->assertJsonPath('data.seed', 'daily-seed')
            ->assertJsonPath('data.shared_seed', true);
        $this->assertSame($daily->id, Run::query()->sole()->daily_game_id);
    }

    // the top of the daily game: without the cheated runs, nor the replays
    public function test_the_scores_of_the_daily_game_leave_out_the_cheated_runs(): void
    {
        $game = $this->game();
        $daily = DailyGame::create(['day' => today()->toDateString(), 'game_id' => $game->id, 'seed' => 'daily-seed', 'contract_score' => 10, 'contract_points' => 5]);
        $fair = Run::factory()->for($game)->create(['daily_game_id' => $daily->id, 'seed' => 'daily-seed', 'score' => 50, 'replay' => 'replay-data']);
        Run::factory()->for($game)->create(['daily_game_id' => $daily->id, 'seed' => 'daily-seed', 'score' => 999, 'is_cheat' => true]);
        Sanctum::actingAs($fair->user);

        $this->getJson('/api/daily/scores')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $fair->id)
            ->assertJsonPath('data.0.score', 50)
            ->assertJsonPath('data.0.has_replay', false)
            ->assertJsonPath('data.0.user.display_name', $fair->user->display_name)
            ->assertJsonMissingPath('data.0.replay')
            ->assertJsonPath('position', 1);
    }
}
