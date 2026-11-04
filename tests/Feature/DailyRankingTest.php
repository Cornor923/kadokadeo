<?php

namespace Tests\Feature;

use App\Filament\Resources\Users\Pages\EditUser;
use App\Filament\Resources\Users\RelationManagers\DailyRunsRelationManager;
use App\Models\DailyGame;
use App\Models\DailyRankingResult;
use App\Models\Game;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use App\Services\DailyRankingService;
use App\Services\RunService;
use App\Settings\SiteSettings;
use App\Support\ScoreBoards;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Livewire\Livewire;
use Tests\Concerns\PlayableGames;
use Tests\TestCase;

// the ranking of the daily game over a period (App\Services\DailyRankingService)
class DailyRankingTest extends TestCase
{
    use PlayableGames, RefreshDatabase;

    private Period $period;

    private Game $game;

    protected function setUp(): void
    {
        parent::setUp();
        $this->game = Game::factory()->create(['is_active' => true]);
        $this->period = Period::factory()->create([
            'start_at' => now()->subDays(20)->startOfDay(),
            'end_at' => now()->subDays(7)->endOfDay(),
        ]);
        $this->setSettings(SiteSettings::class, ['daily_ranking_kado_per_point' => 10]);
    }

    private function dailyGame(Carbon $day): DailyGame
    {
        return DailyGame::query()->create([
            'day' => $day->toDateString(),
            'game_id' => $this->game->id,
            'seed' => 'seed',
            'contract_score' => 100,
            'contract_points' => 10,
        ]);
    }

    private function dailyRun(DailyGame $dailyGame, User $user, int $score, array $attributes = []): Run
    {
        return Run::factory()->for($this->game)->for($user)->create($attributes + [
            'period_id' => null,
            'daily_game_id' => $dailyGame->id,
            'score' => $score,
            'play_time_seconds' => 10,
        ]);
    }

    private function points(?Period $period = null): array
    {
        return app(DailyRankingService::class)->standings($period ?? $this->period)->pluck('points', 'user_id')->all();
    }

    public function test_the_top_10_of_each_day_gets_11_minus_its_position_and_the_days_add_up(): void
    {
        $players = User::factory()->count(11)->create()->values();
        $firstDay = $this->dailyGame($this->period->start_at);
        foreach ($players as $index => $player) {
            $this->dailyRun($firstDay, $player, 1000 - $index);
        }
        $secondDay = $this->dailyGame($this->period->end_at);
        $this->dailyRun($secondDay, $players[10], 500);
        $this->dailyRun($secondDay, $players[0], 400);

        $points = $this->points();

        $this->assertSame(19, $points[$players[0]->id]);
        $this->assertSame(9, $points[$players[1]->id]);
        $this->assertSame(1, $points[$players[9]->id]);
        $this->assertSame(10, $points[$players[10]->id]);
    }

    public function test_a_player_counts_once_a_day_with_the_same_order_as_the_leaderboards(): void
    {
        [$first, $second] = User::factory()->count(2)->create();
        $dailyGame = $this->dailyGame($this->period->start_at);
        $this->dailyRun($dailyGame, $second, 900, ['play_time_seconds' => 20]);
        $this->dailyRun($dailyGame, $first, 900, ['play_time_seconds' => 10]);
        $this->dailyRun($dailyGame, $first, 100);

        $this->assertSame([$first->id => 10, $second->id => 9], $this->points());
    }

    public function test_cheats_deleted_runs_and_the_days_of_another_period_do_not_count(): void
    {
        [$cheater, $deleted, $elsewhere, $player] = User::factory()->count(4)->create();
        $dailyGame = $this->dailyGame($this->period->start_at);
        $this->dailyRun($dailyGame, $cheater, 900, ['is_cheat' => true]);
        $this->dailyRun($dailyGame, $deleted, 800)->delete();
        $this->dailyRun($this->dailyGame($this->period->end_at->copy()->addDay()), $elsewhere, 700);
        $this->dailyRun($dailyGame, $player, 600);

        $this->assertSame([$player->id => 10], $this->points());
    }

    public function test_players_with_the_same_points_share_their_rank(): void
    {
        [$alice, $bob, $chloe, $dan] = User::factory()->count(4)->sequence(
            ['display_name' => 'Alice'], ['display_name' => 'Bob'], ['display_name' => 'Chloé'], ['display_name' => 'Dan'],
        )->create();
        $firstDay = $this->dailyGame($this->period->start_at);
        $this->dailyRun($firstDay, $alice, 900); // 10
        $this->dailyRun($firstDay, $bob, 800); // 9
        $this->dailyRun($firstDay, $dan, 700); // 8
        $secondDay = $this->dailyGame($this->period->end_at);
        $this->dailyRun($secondDay, $chloe, 900); // 10
        $this->dailyRun($secondDay, $dan, 800); // 9
        $this->dailyRun($secondDay, $alice, 700); // 8
        $this->dailyRun($secondDay, $bob, 600); // 7

        $standings = app(DailyRankingService::class)->standings($this->period);

        $this->assertSame([$alice->id, $dan->id, $bob->id, $chloe->id], $standings->pluck('user_id')->all());
        $this->assertSame([18, 17, 16, 10], $standings->pluck('points')->all());
        $this->assertSame([1, 2, 3, 4], $standings->pluck('rank')->all());

        $this->dailyRun($firstDay, $chloe, 650); // 7: 17, as Dan
        $standings = app(DailyRankingService::class)->standings($this->period);
        $this->assertSame([1, 2, 2, 3], $standings->pluck('rank')->all());
    }

    public function test_the_close_pays_every_player_with_points_once_and_never_on_a_run(): void
    {
        $players = User::factory()->count(12)->create(['kado_points' => 0])->values();
        foreach (range(0, 1) as $day) {
            $dailyGame = $this->dailyGame($this->period->start_at->copy()->addDays($day));
            foreach (range(0, 9) as $index) {
                $this->dailyRun($dailyGame, $players[$index + $day * 2], 1000 - $index);
            }
        }

        $service = app(DailyRankingService::class);
        $service->closePeriod($this->period);
        $service->closePeriod($this->period);

        // the 12th of the period has 1 point: paid too
        $this->assertSame(12, DailyRankingResult::query()->count());
        $this->assertSame(10, (int) $players[11]->fresh()->kado_points);
        $this->assertSame(100, (int) $players[0]->fresh()->kado_points);
        $result = DailyRankingResult::query()->where('user_id', $players[11]->id)->firstOrFail();
        $this->assertSame(1, $result->points);
        // (two players with 10 points share the 5th rank)
        $this->assertSame(11, $result->rank_position);
        $this->assertSame(DailyRankingResult::class, $result->userPoint->source_type);
        $this->assertSame('daily ranking', $result->userPoint->reason);
        $this->assertSame(1, $players[0]->userPoints()->count());
    }

    public function test_a_cheat_found_after_the_close_changes_nothing(): void
    {
        [$cheater, $player] = User::factory()->count(2)->create(['kado_points' => 0]);
        $dailyGame = $this->dailyGame($this->period->start_at);
        $run = $this->dailyRun($dailyGame, $cheater, 900, ['contract_points' => 0]);
        $this->dailyRun($dailyGame, $player, 800);
        app(DailyRankingService::class)->closePeriod($this->period);

        app(RunService::class)->flagAsCheat($run);
        app(DailyRankingService::class)->closePeriod($this->period);

        $this->assertSame(100, (int) $cheater->fresh()->kado_points);
        $this->assertSame(90, (int) $player->fresh()->kado_points);
    }

    public function test_at_zero_kado_by_point_the_results_are_kept_and_nothing_is_paid(): void
    {
        $this->setSettings(SiteSettings::class, ['daily_ranking_kado_per_point' => 0]);
        $player = User::factory()->create(['kado_points' => 0]);
        $this->dailyRun($this->dailyGame($this->period->start_at), $player, 900);

        app(DailyRankingService::class)->closePeriod($this->period);

        $this->assertSame(0, (int) $player->fresh()->kado_points);
        $this->assertSame(10, DailyRankingResult::query()->firstOrFail()->points);
        $this->assertSame(0, $player->userPoints()->count());
    }

    public function test_the_api_gives_the_ranking_of_the_current_period_with_today(): void
    {
        Period::factory()->create(['start_at' => now()->subDay(), 'end_at' => now()->addDays(12)]);
        [$player, $viewer] = User::factory()->count(2)->create();
        $this->dailyRun($this->dailyGame(now()), $player, 900);
        $this->dailyRun($this->dailyGame($this->period->start_at), $viewer, 900);

        $this->actingAs($viewer, 'web')
            ->withHeader('Referer', config('app.url'))
            ->getJson('/api/daily/standings')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.points', 10)
            ->assertJsonPath('data.0.rank', 1)
            ->assertJsonPath('data.0.user.display_name', $player->display_name)
            ->assertJsonMissingPath('data.0.user_id');
    }

    public function test_the_ranking_of_the_pages_is_kept_until_the_scores_change(): void
    {
        Period::factory()->create(['start_at' => now()->subDay(), 'end_at' => now()->addDays(12)]);
        $dailyGame = $this->dailyGame(now());
        $first = $this->dailyRun($dailyGame, User::factory()->create(), 900);
        $service = app(DailyRankingService::class);
        $this->assertCount(1, $service->currentStandings());

        $second = $this->dailyRun($dailyGame, User::factory()->create(), 800);
        $this->assertCount(1, $service->currentStandings());

        // inside a transaction, as the moderation: forgotten once the run is really gone
        DB::transaction(function () use ($second, $service) {
            ScoreBoards::dailyChanged($second->daily_game_id);
            $service->currentStandings();
            $second->delete();
        });
        $this->assertCount(1, $service->currentStandings());

        $this->dailyRun($dailyGame, User::factory()->create(), 700);
        ScoreBoards::dailyChanged($first->daily_game_id);
        $this->assertCount(2, $service->currentStandings());
    }

    public function test_the_daily_scores_follow_the_order_of_the_ranking(): void
    {
        [$first, $second] = User::factory()->count(2)->create();
        $dailyGame = $this->dailyGame(now());
        $this->dailyRun($dailyGame, $second, 900, ['play_time_seconds' => 20]);
        $this->dailyRun($dailyGame, $first, 900, ['play_time_seconds' => 10]);

        $this->actingAs($first, 'web')
            ->withHeader('Referer', config('app.url'))
            ->getJson('/api/daily/scores')
            ->assertOk()
            ->assertJsonPath('position', 1)
            ->assertJsonPath('data.0.rank_position', 1)
            ->assertJsonPath('data.0.user.display_name', $first->display_name)
            ->assertJsonPath('data.1.rank_position', 2);
    }

    public function test_the_game_of_the_day_comes_with_its_controls(): void
    {
        $this->game->controls()->create(['keys' => ['space'], 'description' => 'Sauter']);
        $this->dailyGame(now());

        $this->actingAs(User::factory()->create(), 'web')
            ->withHeader('Referer', config('app.url'))
            ->getJson('/api/daily/game')
            ->assertOk()
            ->assertJsonCount(1, 'data.controls');
    }

    public function test_the_admin_looks_into_the_daily_runs_of_a_player(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));
        [$player, $other] = User::factory()->count(2)->create();
        $dailyGame = $this->dailyGame($this->period->start_at);
        $this->dailyRun($dailyGame, $other, 900);
        $ranked = $this->dailyRun($dailyGame, $player, 800);
        $cheated = $this->dailyRun($this->dailyGame($this->period->end_at), $player, 900, ['is_cheat' => true]);
        $normal = Run::factory()->for($this->game)->for($player)->create(['period_id' => $this->period->id]);

        $rankings = 0;
        DB::listen(function ($query) use (&$rankings) {
            $rankings += str_contains($query->sql, 'rank_position') ? 1 : 0;
        });

        Livewire::test(DailyRunsRelationManager::class, ['ownerRecord' => $player, 'pageClass' => EditUser::class])
            ->assertCanSeeTableRecords([$ranked, $cheated])
            ->assertCanNotSeeTableRecords([$normal])
            ->assertTableColumnStateSet('position', 2, $ranked)
            ->assertTableColumnStateSet('ranking_points', 9, $ranked)
            ->assertTableColumnStateSet('position', null, $cheated)
            ->assertTableColumnStateSet('ranking_points', null, $cheated);
        // one query for the page, not one for each row
        $this->assertSame(1, $rankings);
    }
}
