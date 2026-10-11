<?php

namespace Tests\Feature;

use App\Models\DailyGame;
use App\Models\Game;
use App\Models\League;
use App\Models\LeagueMembership;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use App\Services\ScoreService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ScoreServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_competition_can_load_a_previous_period(): void
    {
        $currentPeriod = Period::factory()->create([
            'start_at' => now()->subDay(),
            'end_at' => now()->addDay(),
        ]);
        $previousPeriod = Period::factory()->create([
            'start_at' => now()->subDays(2),
            'end_at' => now()->subDay(),
        ]);
        $game = Game::factory()->create([
            'is_active' => true,
            'score_rankv1' => 40,
        ]);
        $currentPlayer = User::factory()->create(['display_name' => 'Current player']);
        $previousPlayer = User::factory()->create(['display_name' => 'Previous player']);
        $zeroScorePlayer = User::factory()->create(['display_name' => 'Zero score player']);

        Run::factory()->for($currentPeriod)->for($game)->for($currentPlayer)->create(['score' => 1000]);
        Run::factory()->for($previousPeriod)->for($game)->for($previousPlayer)->create(['score' => 2000]);
        Run::factory()->for($previousPeriod)->for($game)->for($zeroScorePlayer)->create(['score' => 0]);

        $user = User::factory()->create();
        $token = $user->createToken('kadokadeo')->plainTextToken;
        $this->withToken($token)
            ->getJson('/api/competition?period='.$previousPeriod->id)
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonPath('0.user.display_name', 'Previous player')
            ->assertJsonPath('0.score', 1500)
            ->assertJsonPath('0.games.0.game.name', $game->name)
            ->assertJsonPath('0.games.0.score', 1500);
    }

    public function test_ranking_v1_interpolates_between_the_four_score_thresholds(): void
    {
        $service = app(ScoreService::class);
        $thresholds = [100, 200, 300];

        foreach ([0 => 0, 50 => 500, 100 => 1000, 150 => 1050, 200 => 1100, 250 => 1125, 300 => 1150, 400 => 1325, 500 => 1500, 600 => 1500] as $score => $points) {
            $this->assertSame($points, $service->calculateScoreOn1500($score, $thresholds, 500));
        }

        $this->assertSame(0, $service->calculateScoreOn1500(400, $thresholds));
        $this->assertSame(0, $service->calculateScoreOn1500(400, $thresholds, 300));
        $this->assertSame(0, $service->calculateScoreOn1500(400, [], 500));
    }

    public function test_leaderboard_uses_each_players_best_run_only(): void
    {
        $game = Game::factory()->create();
        $playerA = User::factory()->create();
        $playerB = User::factory()->create();

        $bestRun = Run::factory()->for($game)->for($playerA)->create([
            'score' => 200000,
            'play_time_seconds' => 30,
            'completed_at' => now()->subMinutes(3),
        ]);
        Run::factory()->for($game)->for($playerA)->create([
            'score' => 150000,
            'play_time_seconds' => 20,
            'completed_at' => now()->subMinutes(2),
        ]);
        $secondPlayerRun = Run::factory()->for($game)->for($playerB)->create([
            'score' => 140000,
            'play_time_seconds' => 10,
            'completed_at' => now()->subMinute(),
        ]);

        $leaderboard = app(ScoreService::class)->getLeaderBoard($game)->get();

        $this->assertCount(2, $leaderboard);
        $this->assertSame([$bestRun->id, $secondPlayerRun->id], $leaderboard->pluck('id')->all());
        $this->assertSame([1, 2], $leaderboard->pluck('rank_position')->all());
    }

    public function test_leaderboard_uses_same_league(): void
    {
        $game = Game::factory()->create();
        $leagueA = League::where('level', 1)->first();
        $leagueB = League::where('level', 2)->first();
        $playerA = User::factory()->create();
        $playerB = User::factory()->create();
        $playerC = User::factory()->create();
        $playerD = User::factory()->create();

        $runA = Run::factory()->for($game)->for($playerA)->for($leagueA)->create([
            'score' => 200000,
            'play_time_seconds' => 30,
            'completed_at' => now()->subMinutes(3),
        ]);
        $runB = Run::factory()->for($game)->for($playerB)->for($leagueA)->create([
            'score' => 150000,
            'play_time_seconds' => 20,
            'completed_at' => now()->subMinutes(2),
        ]);
        $runC = Run::factory()->for($game)->for($playerC)->for($leagueB)->create([
            'score' => 160000,
            'play_time_seconds' => 10,
            'completed_at' => now()->subMinute(),
        ]);
        $runD = Run::factory()->for($game)->for($playerD)->for($leagueB)->create([
            'score' => 110000,
            'play_time_seconds' => 10,
            'completed_at' => now()->subMinute(),
        ]);

        $leaderboardA = app(ScoreService::class)->getLeaderBoard($game, null, $leagueA->id)->get();
        $leaderboardB = app(ScoreService::class)->getLeaderBoard($game, null, $leagueB->id)->get();

        $this->assertCount(2, $leaderboardA);
        $this->assertCount(2, $leaderboardB);
        $this->assertSame([$runA->id, $runB->id], $leaderboardA->pluck('id')->all());
        $this->assertSame([1, 2], $leaderboardA->pluck('rank_position')->all());
        $this->assertSame([$runC->id, $runD->id], $leaderboardB->pluck('id')->all());
        $this->assertSame([1, 2], $leaderboardB->pluck('rank_position')->all());
    }

    public function test_user_best_runs_positions_ignore_other_runs_from_same_player(): void
    {
        $period = Period::factory()->create();
        $game = Game::factory()->create();
        $league = League::where('level', 1)->first();
        $playerA = User::factory()->create();
        $playerB = User::factory()->create();

        LeagueMembership::factory()->for($period)->for($game)->for($league)->for($playerA)->create();
        LeagueMembership::factory()->for($period)->for($game)->for($league)->for($playerB)->create();

        Run::factory()->for($period)->for($game)->for($league)->for($playerA)->create([
            'score' => 200000,
            'play_time_seconds' => 30,
            'completed_at' => now()->subMinutes(3),
        ]);
        Run::factory()->for($period)->for($game)->for($league)->for($playerA)->create([
            'score' => 150000,
            'play_time_seconds' => 20,
            'completed_at' => now()->subMinutes(2),
        ]);
        $secondPlayerRun = Run::factory()->for($period)->for($game)->for($league)->for($playerB)->create([
            'score' => 140000,
            'play_time_seconds' => 10,
            'completed_at' => now()->subMinute(),
        ]);

        $bestRuns = app(ScoreService::class)->getUserBestRuns($playerB, $period->id);

        $this->assertCount(1, $bestRuns);
        $this->assertSame($secondPlayerRun->id, $bestRuns->first()->id);
        $this->assertSame(2, (int) $bestRuns->first()->league_rank);
    }

    public function test_user_best_runs_positions_use_players_league_for_each_game(): void
    {
        $period = Period::factory()->create();
        $game = Game::factory()->create();
        $leagueA = League::where('level', 1)->first();
        $leagueB = League::where('level', 2)->first();
        $playerA = User::factory()->create();
        $playerB = User::factory()->create();
        $playerC = User::factory()->create();

        LeagueMembership::factory()->for($period)->for($game)->for($leagueA)->for($playerA)->create();
        LeagueMembership::factory()->for($period)->for($game)->for($leagueB)->for($playerB)->create();
        LeagueMembership::factory()->for($period)->for($game)->for($leagueB)->for($playerC)->create();

        Run::factory()->for($period)->for($game)->for($leagueA)->for($playerA)->create([
            'score' => 200000,
            'play_time_seconds' => 30,
            'completed_at' => now()->subMinutes(3),
        ]);
        $bestLeagueBRun = Run::factory()->for($period)->for($game)->for($leagueB)->for($playerB)->create([
            'score' => 150000,
            'play_time_seconds' => 20,
            'completed_at' => now()->subMinutes(2),
        ]);
        Run::factory()->for($period)->for($game)->for($leagueB)->for($playerC)->create([
            'score' => 100000,
            'play_time_seconds' => 10,
            'completed_at' => now()->subMinute(),
        ]);

        $bestRuns = app(ScoreService::class)->getUserBestRuns($playerB, $period->id);

        $this->assertCount(1, $bestRuns);
        $this->assertSame($bestLeagueBRun->id, $bestRuns->first()->id);
        $this->assertSame(1, (int) $bestRuns->first()->league_rank);
    }

    public function test_daily_game_position_uses_each_players_best_run_only(): void
    {
        $game = Game::factory()->create();
        $dailyGame = DailyGame::query()->create([
            'day' => now()->toDateString(),
            'game_id' => $game->id,
            'seed' => 'daily-seed',
            'contract_score' => 100,
            'contract_points' => 10,
        ]);
        $playerA = User::factory()->create();
        $playerB = User::factory()->create();

        Run::factory()->for($game)->for($playerA)->create([
            'daily_game_id' => $dailyGame->id,
            'score' => 200000,
            'play_time_seconds' => 30,
            'completed_at' => now()->subMinutes(3),
        ]);
        Run::factory()->for($game)->for($playerA)->create([
            'daily_game_id' => $dailyGame->id,
            'score' => 150000,
            'play_time_seconds' => 20,
            'completed_at' => now()->subMinutes(2),
        ]);
        Run::factory()->for($game)->for($playerB)->create([
            'daily_game_id' => $dailyGame->id,
            'score' => 140000,
            'play_time_seconds' => 10,
            'completed_at' => now()->subMinute(),
        ]);

        $scoreService = app(ScoreService::class);

        $this->assertSame(1, $scoreService->getUserPositionOnDailyGame($dailyGame, $playerA->id));
        $this->assertSame(2, $scoreService->getUserPositionOnDailyGame($dailyGame, $playerB->id));
    }
}
