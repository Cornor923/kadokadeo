<?php

namespace Tests\Feature;

use App\Models\Clan;
use App\Models\ClanAction;
use App\Models\DailyGame;
use App\Models\Game;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\EnablesClans;
use Tests\Concerns\PlayableGames;
use Tests\TestCase;

// "Changer de partie" (RunController::reroll)
class RunRerollTest extends TestCase
{
    use EnablesClans, PlayableGames, RefreshDatabase;

    private function begin(Game $game): string
    {
        return $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful()->json('data.run_id');
    }

    public function test_the_run_begun_is_replaced_by_a_new_one_with_a_new_seed(): void
    {
        config(['kado.games_per_day' => 10]);
        $user = User::factory()->create(['kado_games' => 5]);
        $game = Game::factory()->create();
        Sanctum::actingAs($user);

        $runId = $this->begin($game);
        $seed = Run::query()->find($runId)->seed;
        $this->assertSame(4, $user->fresh()->kado_games);

        $response = $this->postJson("/api/runs/{$runId}/reroll")->assertSuccessful()
            ->assertJsonPath('data.contract_score', 0)
            ->assertJsonPath('data.shared_seed', false);

        $this->assertNull(Run::withTrashed()->find($runId));
        $newRun = Run::query()->findOrFail($response->json('data.run_id'));
        $this->assertNotSame($seed, $newRun->seed);
        $this->assertSame($response->json('data.seed'), $newRun->seed);
        $this->assertSame($game->id, $newRun->game_id);
        $this->assertNull($newRun->completed_at);
        // paid like a run begun
        $this->assertSame(3, $user->fresh()->kado_games);
    }

    public function test_without_games_left_the_run_begun_goes_on(): void
    {
        config(['kado.games_per_day' => 10]);
        $user = User::factory()->create(['kado_games' => 0]);
        $run = Run::factory()->for(Game::factory())->for($user)->create(['score' => 0, 'completed_at' => null]);
        Sanctum::actingAs($user);

        $this->postJson("/api/runs/{$run->id}/reroll")->assertForbidden();

        $this->assertNotNull(Run::query()->find($run->id));
        $this->assertSame(1, Run::query()->count());
    }

    public function test_only_a_run_begun_by_the_player_outside_the_daily_game(): void
    {
        $user = User::factory()->create();
        $game = Game::factory()->create();
        Sanctum::actingAs($user);

        $other = Run::factory()->for($game)->for(User::factory())->create(['score' => 0, 'completed_at' => null]);
        $this->postJson("/api/runs/{$other->id}/reroll")->assertForbidden();

        $finished = Run::factory()->for($game)->for($user)->create(['score' => 10, 'completed_at' => now()]);
        $this->postJson("/api/runs/{$finished->id}/reroll")->assertStatus(409);

        $daily = DailyGame::query()->create(['day' => now()->toDateString(), 'game_id' => $game->id, 'seed' => 'abc', 'contract_score' => 100, 'contract_points' => 5]);
        $dailyRun = Run::factory()->for($game)->for($user)->create(['score' => 0, 'completed_at' => null, 'seed' => 'abc', 'daily_game_id' => $daily->id]);
        $this->postJson("/api/runs/{$dailyRun->id}/reroll")->assertForbidden();

        $this->assertSame(3, Run::query()->count());
    }

    public function test_the_clan_run_goes_on_with_the_new_run(): void
    {
        Period::factory()->create(['start_at' => now()->subDay()->startOfDay(), 'end_at' => now()->addDays(12)->endOfDay()]);
        $attacker = User::factory()->create(['clan_attack_games' => 3]);
        Clan::factory()->withLeader($attacker)->create();
        $clanB = Clan::factory()->withLeader(User::factory()->create())->create();
        $game = Game::factory()->create();
        Sanctum::actingAs($attacker);

        $this->postJson("/api/clans/{$clanB->id}/attacks", ['game_id' => $game->id])->assertCreated();
        $runId = $this->begin($game);
        $this->assertSame(2, $attacker->fresh()->clan_attack_games);

        $newRunId = $this->postJson("/api/runs/{$runId}/reroll")->assertSuccessful()
            ->assertJsonPath('data.clan.type', 'attack')
            ->json('data.run_id');

        $this->assertSame($newRunId, ClanAction::query()->sole()->run_id);
        // an attack game, like a run begun
        $this->assertSame(1, $attacker->fresh()->clan_attack_games);
    }

    public function test_its_own_rate_limit(): void
    {
        config(['kado.games_per_day' => 0]);
        $user = User::factory()->create();
        $game = Game::factory()->create();
        Sanctum::actingAs($user);

        $runId = $this->begin($game);
        for ($i = 0; $i < 60; $i++) {
            $runId = $this->postJson("/api/runs/{$runId}/reroll")->assertSuccessful()->json('data.run_id');
        }
        $this->postJson("/api/runs/{$runId}/reroll")->assertStatus(429);
        // not counted with the runs begun
        $this->begin($game);
    }
}
