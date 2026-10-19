<?php

namespace Tests\Feature;

use App\Models\Game;
use App\Models\League;
use App\Models\LeagueMembership;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use App\Services\ClanPeriodService;
use App\Services\LeagueService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PeriodCloseConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_membership_inserted_by_a_concurrent_request_is_read_again(): void
    {
        $leagueService = app(LeagueService::class);
        $beginner = $leagueService->getBeginnerLeague();
        $confirmed = League::query()->where('level', 2)->firstOrFail();
        $period = Period::factory()->create();
        $game = Game::factory()->create(['name' => 'Kaskade']);
        $user = User::factory()->create();

        // the period close inserts the membership between the read and the insert of the run start (resolveMembership)
        $inserted = false;
        DB::listen(function ($query) use (&$inserted, $user, $period, $game, $confirmed) {
            if ($inserted || !str_starts_with($query->sql, 'select') || !str_contains($query->sql, 'league_memberships')) {
                return;
            }
            $inserted = true;
            DB::table('league_memberships')->insert([
                'user_id' => $user->id,
                'period_id' => $period->id,
                'game_id' => $game->id,
                'league_id' => $confirmed->id,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        });

        $storeHighestMembership = fn (...$args) => $this->storeHighestMembership(...$args);
        $membership = DB::transaction(fn () => $storeHighestMembership->call($leagueService, $user->id, $game->id, $period->id, $beginner));

        $this->assertSame($confirmed->id, $membership->league_id);
        $this->assertSame(1, LeagueMembership::query()->where('user_id', $user->id)->count());
    }

    public function test_new_period_is_rolled_back_when_the_league_close_fails(): void
    {
        $this->travelTo(now()->next('Monday')->startOfDay()->addSeconds(5));
        $period = Period::factory()->create([
            'start_at' => now()->subDays(14),
            'end_at' => now()->subSecond(),
        ]);

        $this->mock(LeagueService::class)
            ->shouldReceive('closePeriod')
            ->once()
            ->andThrow(new \RuntimeException('close failed'));

        try {
            $this->artisan('kado:prepare-new-period')->run();
            $this->fail('The close should fail.');
        } catch (\RuntimeException $e) {
            $this->assertSame('close failed', $e->getMessage());
        }

        $this->assertSame([$period->id], Period::query()->pluck('id')->all());
    }

    // the rewards of the closed period (feathers, clans) come after the commit of the new period: a failure there leaves it
    public function test_new_period_stays_when_the_rewards_of_the_closed_period_fail(): void
    {
        $this->travelTo(now()->next('Monday')->startOfDay()->addSeconds(5));
        $beginner = app(LeagueService::class)->getBeginnerLeague();
        $period = Period::factory()->create([
            'start_at' => now()->subDays(14),
            'end_at' => now()->subSecond(),
        ]);
        $game = Game::factory()->create(['name' => 'Kaskade']);
        $user = User::factory()->create();
        LeagueMembership::factory()->for($user)->for($period)->for($game)->for($beginner, 'league')->create();

        $this->mock(ClanPeriodService::class)
            ->shouldReceive('closePeriod')
            ->once()
            ->andThrow(new \RuntimeException('close failed'));

        try {
            $this->artisan('kado:prepare-new-period')->run();
            $this->fail('The close should fail.');
        } catch (\RuntimeException $e) {
            $this->assertSame('close failed', $e->getMessage());
        }

        $newPeriod = Period::current()->firstOrFail();
        $this->assertNotSame($period->id, $newPeriod->id);
        $this->assertDatabaseHas('league_memberships', ['user_id' => $user->id, 'period_id' => $newPeriod->id]);
    }

    public function test_middle_of_period_monday_does_not_close_the_previous_period_again(): void
    {
        $this->travelTo(now()->next('Monday')->startOfDay()->addSeconds(5));
        $beginner = app(LeagueService::class)->getBeginnerLeague();
        $previousPeriod = Period::factory()->create([
            'start_at' => now()->subDays(21),
            'end_at' => now()->subDays(7)->subSecond(),
        ]);
        $period = Period::factory()->create([
            'start_at' => now()->subDays(7),
            'end_at' => now()->addDays(7)->subSecond(),
        ]);
        $game = Game::factory()->create(['name' => 'Kaskade']);
        $user = User::factory()->create();
        LeagueMembership::factory()->for($user)->for($previousPeriod)->for($game)->for($beginner, 'league')->create();
        // finished after the close of its period (started before its end)
        Run::factory()->for($previousPeriod)->for($game)->for($user)->for($beginner, 'league')->create(['score' => 100]);

        $this->artisan('kado:prepare-new-period')->assertSuccessful();

        $this->assertSame([$previousPeriod->id, $period->id], Period::query()->orderBy('id')->pluck('id')->all());
        $this->assertDatabaseCount('league_promotions', 0);
        $this->assertDatabaseMissing('league_memberships', ['period_id' => $period->id]);
    }

    // during the close the new period is not committed yet: a run started then does not wait, it is outside of any period
    public function test_a_run_started_during_the_close_is_outside_of_any_period(): void
    {
        $this->travelTo(now()->next('Monday')->startOfDay()->addSeconds(5));
        Period::factory()->create([
            'start_at' => now()->subDays(14),
            'end_at' => now()->subSecond(),
        ]);
        $game = Game::factory()->create(['name' => 'Kaskade']);
        Sanctum::actingAs(User::factory()->create());

        $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful();

        $this->assertNull(Run::query()->sole()->period_id);
    }

    public function test_new_period_starts_with_the_carried_memberships(): void
    {
        $this->travelTo(now()->next('Monday')->startOfDay()->addSeconds(5));
        $beginner = app(LeagueService::class)->getBeginnerLeague();
        $period = Period::factory()->create([
            'start_at' => now()->subDays(14),
            'end_at' => now()->subSecond(),
        ]);
        $game = Game::factory()->create(['name' => 'Kaskade']);
        $user = User::factory()->create();
        LeagueMembership::factory()->for($user)->for($period)->for($game)->for($beginner, 'league')->create();

        $this->artisan('kado:prepare-new-period')->assertSuccessful();

        $newPeriod = Period::current()->firstOrFail();
        $this->assertNotSame($period->id, $newPeriod->id);
        $this->assertDatabaseHas('league_memberships', [
            'user_id' => $user->id,
            'period_id' => $newPeriod->id,
            'game_id' => $game->id,
            'league_id' => $beginner->id,
        ]);
    }
}
