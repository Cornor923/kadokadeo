<?php

namespace Tests\Feature;

use App\Models\Game;
use App\Models\League;
use App\Models\LeagueMembership;
use App\Models\Period;
use App\Models\PoidsPlumeResult;
use App\Models\Run;
use App\Models\User;
use App\Services\LeagueService;
use App\Services\PoidsPlumeService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LeagueSystemTest extends TestCase
{
    use RefreshDatabase;

    public function test_period_close_promotes_fastest_tied_player_and_is_idempotent(): void
    {
        $leagueService = app(LeagueService::class);
        $beginner = $leagueService->getBeginnerLeague();
        $confirmed = League::query()->where('level', 2)->firstOrFail();
        $period = Period::factory()->create();
        $nextPeriod = Period::factory()->create();
        $game = Game::factory()->create(['name' => 'Kaskade']);
        $slowUser = User::factory()->create(['display_name' => 'slow']);
        $fastUser = User::factory()->create(['display_name' => 'fast']);
        $thirdUser = User::factory()->create(['display_name' => 'third']);

        foreach ([$slowUser, $fastUser, $thirdUser] as $user) {
            LeagueMembership::factory()
                ->for($user)
                ->for($period)
                ->for($game)
                ->for($beginner, 'league')
                ->create();
        }

        Run::factory()->for($period)->for($game)->for($slowUser)->for($beginner, 'league')->create(['score' => 100, 'play_time_seconds' => 30]);
        $promotionRun = Run::factory()->for($period)->for($game)->for($fastUser)->for($beginner, 'league')->create(['score' => 100, 'play_time_seconds' => 20]);
        Run::factory()->for($period)->for($game)->for($thirdUser)->for($beginner, 'league')->create(['score' => 50, 'play_time_seconds' => 10]);

        app(LeagueService::class)->closePeriod($period, $nextPeriod);

        $this->assertDatabaseHas('league_promotions', [
            'period_id' => $period->id,
            'next_period_id' => $nextPeriod->id,
            'game_id' => $game->id,
            'user_id' => $fastUser->id,
            'from_league_id' => $beginner->id,
            'to_league_id' => $confirmed->id,
            'run_id' => $promotionRun->id,
            'rank_position' => 1,
            'score' => 100,
            'play_time_seconds' => 20,
            'promotion_slots' => 1,
            'active_players_count' => 3,
            'promotion_reward' => 100,
        ]);

        $this->assertDatabaseHas('league_memberships', [
            'user_id' => $fastUser->id,
            'period_id' => $nextPeriod->id,
            'game_id' => $game->id,
            'league_id' => $confirmed->id,
        ]);
        $this->assertDatabaseHas('league_memberships', [
            'user_id' => $slowUser->id,
            'period_id' => $nextPeriod->id,
            'game_id' => $game->id,
            'league_id' => $beginner->id,
        ]);

        $this->assertSame(100, $fastUser->fresh()->kado_points);
        $this->assertDatabaseCount('league_promotions', 1);
        $this->assertDatabaseCount('user_points', 1);

        app(LeagueService::class)->closePeriod($period, $nextPeriod);

        $this->assertSame(100, $fastUser->fresh()->kado_points);
        $this->assertDatabaseCount('league_promotions', 1);
        $this->assertDatabaseCount('user_points', 1);
    }

    public function test_ratio_promotion_uses_ceiling_without_minimum_player_count(): void
    {
        $leagueService = app(LeagueService::class);
        $beginner = $leagueService->getBeginnerLeague();
        $confirmed = League::query()->where('level', 2)->firstOrFail();
        $period = Period::factory()->create();
        $nextPeriod = Period::factory()->create();
        $game = Game::factory()->create(['name' => 'Solo']);
        $user = User::factory()->create(['display_name' => 'solo']);
        $nextLeagueUser = User::factory()->create(['display_name' => 'confirmed']);

        LeagueMembership::factory()->for($user)->for($period)->for($game)->for($beginner, 'league')->create();
        LeagueMembership::factory()->for($nextLeagueUser)->for($period)->for($game)->for($confirmed, 'league')->create();

        $promotionRun = Run::factory()->for($period)->for($game)->for($user)->for($beginner, 'league')->create(['score' => 10, 'play_time_seconds' => 20]);

        app(LeagueService::class)->closePeriod($period, $nextPeriod);

        $this->assertDatabaseHas('league_promotions', [
            'period_id' => $period->id,
            'game_id' => $game->id,
            'user_id' => $user->id,
            'to_league_id' => $confirmed->id,
            'run_id' => $promotionRun->id,
            'promotion_slots' => 1,
            'active_players_count' => 1,
        ]);
    }

    public function test_period_close_does_not_promote_lone_player_when_next_league_is_empty(): void
    {
        $leagueService = app(LeagueService::class);
        $beginner = $leagueService->getBeginnerLeague();
        $period = Period::factory()->create();
        $nextPeriod = Period::factory()->create();
        $game = Game::factory()->create(['name' => 'Empty Next League']);
        $user = User::factory()->create(['display_name' => 'lone-player']);

        LeagueMembership::factory()->for($user)->for($period)->for($game)->for($beginner, 'league')->create();

        Run::factory()->for($period)->for($game)->for($user)->for($beginner, 'league')->create(['score' => 10, 'play_time_seconds' => 20]);

        app(LeagueService::class)->closePeriod($period, $nextPeriod);

        $this->assertDatabaseCount('league_promotions', 0);
        $this->assertDatabaseHas('league_memberships', [
            'user_id' => $user->id,
            'period_id' => $nextPeriod->id,
            'game_id' => $game->id,
            'league_id' => $beginner->id,
        ]);
    }

    public function test_period_close_promotes_lone_player_when_next_league_has_active_players(): void
    {
        $leagueService = app(LeagueService::class);
        $beginner = $leagueService->getBeginnerLeague();
        $confirmed = League::query()->where('level', 2)->firstOrFail();
        $period = Period::factory()->create();
        $nextPeriod = Period::factory()->create();
        $game = Game::factory()->create(['name' => 'Active Next League']);
        $loneUser = User::factory()->create(['display_name' => 'lone-promoted']);
        $confirmedUser = User::factory()->create(['display_name' => 'active-confirmed']);

        LeagueMembership::factory()->for($loneUser)->for($period)->for($game)->for($beginner, 'league')->create();
        LeagueMembership::factory()->for($confirmedUser)->for($period)->for($game)->for($confirmed, 'league')->create();

        $promotionRun = Run::factory()->for($period)->for($game)->for($loneUser)->for($beginner, 'league')->create(['score' => 10, 'play_time_seconds' => 20]);
        Run::factory()->for($period)->for($game)->for($confirmedUser)->for($confirmed, 'league')->create(['score' => 10, 'play_time_seconds' => 20]);

        app(LeagueService::class)->closePeriod($period, $nextPeriod);

        $this->assertDatabaseHas('league_promotions', [
            'period_id' => $period->id,
            'next_period_id' => $nextPeriod->id,
            'game_id' => $game->id,
            'user_id' => $loneUser->id,
            'from_league_id' => $beginner->id,
            'to_league_id' => $confirmed->id,
            'run_id' => $promotionRun->id,
            'rank_position' => 1,
            'promotion_slots' => 1,
            'active_players_count' => 1,
        ]);
        $this->assertDatabaseHas('league_memberships', [
            'user_id' => $loneUser->id,
            'period_id' => $nextPeriod->id,
            'game_id' => $game->id,
            'league_id' => $confirmed->id,
        ]);
    }

    public function test_period_close_does_not_promote_without_required_star(): void
    {
        $leagueService = app(LeagueService::class);
        $beginner = $leagueService->getBeginnerLeague();
        $period = Period::factory()->create();
        $nextPeriod = Period::factory()->create();
        $game = Game::factory()->create(['name' => 'No Star']);
        $user = User::factory()->create(['display_name' => 'no-star']);

        LeagueMembership::factory()->for($user)->for($period)->for($game)->for($beginner, 'league')->create();

        Run::factory()->for($period)->for($game)->for($user)->for($beginner, 'league')->create(['score' => 9, 'play_time_seconds' => 20]);

        app(LeagueService::class)->closePeriod($period, $nextPeriod);

        $this->assertDatabaseCount('league_promotions', 0);
        $this->assertDatabaseHas('league_memberships', [
            'user_id' => $user->id,
            'period_id' => $nextPeriod->id,
            'game_id' => $game->id,
            'league_id' => $beginner->id,
        ]);
    }

    public function test_poids_plume_rewards_are_shared_between_tied_feather_leaders(): void
    {
        config(['kado.poids_plume.jackpot' => 101]);

        $leagueService = app(LeagueService::class);
        $period = Period::factory()->create();
        $beginner = $leagueService->getBeginnerLeague();
        $paradise = $leagueService->getParadiseLeague();
        $gameOne = Game::factory()->create(['name' => 'Bactery']);
        $gameTwo = Game::factory()->create(['name' => 'Opalus']);
        $playerA = User::factory()->create(['display_name' => 'player-a']);
        $playerB = User::factory()->create(['display_name' => 'player-b']);
        $beginnerPlayer = User::factory()->create(['display_name' => 'beginner']);

        Run::factory()->for($period)->for($gameOne)->for($beginnerPlayer)->for($beginner, 'league')->create(['score' => 999, 'play_time_seconds' => 10]);
        Run::factory()->for($period)->for($gameOne)->for($playerA)->for($paradise, 'league')->create(['score' => 100, 'play_time_seconds' => 20]);
        Run::factory()->for($period)->for($gameOne)->for($playerB)->for($paradise, 'league')->create(['score' => 80, 'play_time_seconds' => 10]);
        Run::factory()->for($period)->for($gameTwo)->for($playerA)->for($paradise, 'league')->create(['score' => 100, 'play_time_seconds' => 20]);
        Run::factory()->for($period)->for($gameTwo)->for($playerB)->for($paradise, 'league')->create(['score' => 150, 'play_time_seconds' => 30]);

        app(PoidsPlumeService::class)->closePeriod($period);

        $resultA = PoidsPlumeResult::query()->where('period_id', $period->id)->where('user_id', $playerA->id)->firstOrFail();
        $resultB = PoidsPlumeResult::query()->where('period_id', $period->id)->where('user_id', $playerB->id)->firstOrFail();

        $this->assertEquals([$gameOne->id], $resultA->game_ids);
        $this->assertEquals([$gameTwo->id], $resultB->game_ids);
        $this->assertSame(1, $resultA->feathers_count);
        $this->assertSame(1, $resultB->feathers_count);
        $this->assertSame(50, $resultA->reward);
        $this->assertSame(50, $resultB->reward);
        $this->assertSame(50, $playerA->fresh()->kado_points);
        $this->assertSame(50, $playerB->fresh()->kado_points);
        $this->assertDatabaseMissing('poids_plume_results', ['user_id' => $beginnerPlayer->id]);

        app(PoidsPlumeService::class)->closePeriod($period);

        $this->assertDatabaseCount('poids_plume_results', 2);
        $this->assertDatabaseCount('user_points', 2);
    }

    public function test_current_period_feather_leaderboard_counts_paradise_wins_per_game(): void
    {
        $leagueService = app(LeagueService::class);
        $paradise = $leagueService->getParadiseLeague();
        $currentPeriod = Period::factory()->create([
            'start_at' => now()->subDays(2),
            'end_at' => now()->addDays(11),
        ]);
        $previousPeriod = Period::factory()->create([
            'start_at' => now()->subDays(30),
            'end_at' => now()->subDays(17),
        ]);
        $gameOne = Game::factory()->create(['name' => 'Feather Game One']);
        $gameTwo = Game::factory()->create(['name' => 'Feather Game Two']);
        $gameThree = Game::factory()->create(['name' => 'Feather Game Three']);
        $playerA = User::factory()->create(['display_name' => 'feather-player-a']);
        $playerB = User::factory()->create(['display_name' => 'feather-player-b']);
        $playerWithoutFeathers = User::factory()->create(['display_name' => 'no-feathers']);

        Run::factory()->for($currentPeriod)->for($gameOne)->for($playerWithoutFeathers)
            ->for($leagueService->getBeginnerLeague(), 'league')->create(['score' => 9999]);
        Run::factory()->for($currentPeriod)->for($gameOne)->for($playerA)->for($paradise, 'league')->create(['score' => 100]);
        Run::factory()->for($currentPeriod)->for($gameOne)->for($playerB)->for($paradise, 'league')->create(['score' => 90]);
        Run::factory()->for($currentPeriod)->for($gameTwo)->for($playerA)->for($paradise, 'league')->create(['score' => 100]);
        Run::factory()->for($currentPeriod)->for($gameThree)->for($playerB)->for($paradise, 'league')->create(['score' => 200]);
        Run::factory()->for($previousPeriod)->for($gameTwo)->for($playerB)->for($paradise, 'league')->create(['score' => 1000]);

        $this->actingAs($playerA, 'sanctum')
            ->getJson('/api/competition/poids-plumes')
            ->assertOk()
            ->assertJsonCount(2)
            ->assertJsonPath('0.rank', 1)
            ->assertJsonPath('0.user.display_name', 'feather-player-a')
            ->assertJsonPath('0.feathers_count', 2)
            ->assertJsonPath('1.user.display_name', 'feather-player-b')
            ->assertJsonPath('1.feathers_count', 1);
    }
}
