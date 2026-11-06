<?php

namespace Tests\Feature;

use App\Achievements\Events\GameRunCompleted;
use App\Enums\RunFlagRule;
use App\Jobs\VerifyRunReplay;
use App\Models\AchievementEvent;
use App\Models\AchievementLevel;
use App\Models\Game;
use App\Models\Run;
use App\Models\RunFlag;
use App\Models\User;
use App\Models\UserAchievementProgress;
use App\Services\AchievementService;
use App\Services\ModerationService;
use App\Services\ReplayVerifier;
use App\Services\RunService;
use App\Settings\AntiCheatSettings;
use App\Settings\SiteSettings;
use App\Support\GameBuilds\GameBuildArchive;
use Database\Seeders\AchievementsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use Tests\Unit\ReplayHeaderTest;

class AchievementTakeBackTest extends TestCase
{
    use RefreshDatabase;

    // the stats of a game of Bactery: 5 stars, 25 bacteria (no level of few_bacteria), 20 stones
    private const HONEST = ['k' => 50, 'm' => 25, 'w' => 20, 'b' => 5];

    // 70 stones (stones: 1.000 points) and 0 bacteria (few_bacteria: 1.600 points)
    private const FORGED = ['k' => 25, 'm' => 0, 'w' => 70, 'b' => 5];

    private Game $game;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setSettings(SiteSettings::class, ['achievements_enabled' => true]);
        $this->game = Game::factory()->create(['name' => 'Bactery']);
        $this->seed(AchievementsSeeder::class);
        $this->user = User::factory()->create(['kado_points' => 0]);
    }

    private function countedRun(array $stats, int $score = 100): Run
    {
        $run = Run::factory()->for($this->game)->for($this->user)->create(['score' => $score, 'score_details' => $stats, 'replay' => ReplayHeaderTest::replay(1 | 64)]);
        app(AchievementService::class)->handleGameRunCompleted(new GameRunCompleted($this->user, $this->game, $run, $stats));

        return $run;
    }

    private function points(): int
    {
        return $this->user->fresh()->kado_points;
    }

    private function progress(string $key): UserAchievementProgress
    {
        return UserAchievementProgress::query()->whereHas('achievement', fn ($query) => $query->where('key', $key)->where('game_id', $this->game->id))->sole();
    }

    private function verifying(array $result): void
    {
        $this->app->instance(ReplayVerifier::class, new class(app(GameBuildArchive::class), $result) extends ReplayVerifier
        {
            public function __construct(GameBuildArchive $archive, private array $result)
            {
                parent::__construct($archive);
            }

            public function verify(Run $run, array $input = [], bool $currentBundle = false): array
            {
                return $this->result;
            }
        });
    }

    public function test_only_what_the_run_gave_is_taken_back(): void
    {
        $this->countedRun(self::HONEST);
        $this->countedRun(self::HONEST);
        // total_stars at 10: its first level, 100 points
        $this->assertSame(100, $this->points());

        $forged = $this->countedRun(self::FORGED);
        $this->assertSame(2700, $this->points());
        $this->assertSame(70, $this->progress('stones')->current_value);

        app(AchievementService::class)->takeBackRun($forged);

        $this->assertSame(100, $this->points());
        $this->assertSame(20, $this->progress('stones')->current_value);
        $this->assertSame(0, $this->progress('stones')->completed_level);
        $this->assertNull($this->progress('few_bacteria')->completed_at);
        // the sum of the honest runs, and their level
        $this->assertSame(10, $this->progress('total_stars')->current_value);
        $this->assertSame(1, $this->progress('total_stars')->completed_level);
        $this->assertSame(2600, -(int) $this->user->userPoints()->where('reason', 'achievement taken back')->where('source_type', AchievementLevel::class)->sum('delta'));
    }

    public function test_it_takes_back_once(): void
    {
        $forged = $this->countedRun(self::FORGED);

        app(AchievementService::class)->takeBackRun($forged);
        $points = $this->points();
        app(AchievementService::class)->takeBackRun($forged);

        $this->assertSame($points, $this->points());
        $this->assertSame(0, AchievementEvent::query()->count());
    }

    public function test_a_run_that_did_not_count_takes_nothing(): void
    {
        $this->countedRun(self::FORGED);
        $points = $this->points();

        app(AchievementService::class)->takeBackRun(Run::factory()->for($this->game)->for($this->user)->create(['score_details' => self::FORGED]));

        $this->assertSame($points, $this->points());
    }

    public function test_a_level_the_run_did_not_cross_stays_when_its_target_was_raised(): void
    {
        $this->countedRun(self::HONEST);
        $this->countedRun(self::HONEST);
        $run = $this->countedRun(self::HONEST);
        AchievementLevel::query()->where('title', 'Admirateur d\'astres')->update(['target' => 50]);

        app(AchievementService::class)->takeBackRun($run);

        $this->assertSame(10, $this->progress('total_stars')->current_value);
        $this->assertSame(1, $this->progress('total_stars')->completed_level);
        $this->assertSame(100, $this->points());
    }

    public function test_a_run_found_cheated_gives_nothing_anymore(): void
    {
        $this->countedRun(self::HONEST);
        $forged = $this->countedRun(self::FORGED);

        app(RunService::class)->flagAsCheat($forged);

        $this->assertSame(0, $this->points());
        $this->assertSame(0, $this->progress('stones')->completed_level);
    }

    public function test_a_deleted_run_gives_nothing_until_it_is_restored(): void
    {
        $forged = $this->countedRun(self::FORGED);
        $points = $this->points();

        app(ModerationService::class)->deleteRun($forged);
        $this->assertSame(0, $this->points());

        app(ModerationService::class)->restoreRun($forged);
        $this->assertSame($points, $this->points());
    }

    public function test_a_run_deleted_for_good_is_taken_back_too(): void
    {
        app(ModerationService::class)->deleteRun($this->countedRun(self::FORGED), force: true);

        $this->assertSame(0, $this->points());
    }

    public function test_a_run_counts_with_the_stats_of_its_replay_when_they_differ(): void
    {
        $this->setSettings(AntiCheatSettings::class, ['verifier_enabled' => true]);
        $run = $this->countedRun(self::FORGED);
        $this->verifying(['ok' => true, 'score' => 100, 'frames' => 900, 'stats' => self::HONEST]);

        app()->call([new VerifyRunReplay($run->id), 'handle']);

        $this->assertSame(0, $this->points());
        $this->assertSame(self::HONEST, $run->fresh()->score_details + self::HONEST);
        $this->assertSame(20, $this->progress('stones')->current_value);
        $this->assertSame(1, AchievementEvent::query()->count());
        $flag = RunFlag::query()->where('run_id', $run->id)->sole();
        $this->assertSame(RunFlagRule::STATS_MISMATCH, $flag->rule);
        $this->assertSame(['k', 'm', 'w'], $flag->details['keys']);
        $this->assertFalse($run->fresh()->is_cheat);
    }

    public function test_stats_that_no_rule_reads_may_differ(): void
    {
        $run = $this->countedRun(self::FORGED);
        $points = $this->points();
        // (n: the marbles of the deal in Bactery, no rule reads them; Tubulo sends real times the replay can't give back)
        $this->verifying(['ok' => true, 'score' => 100, 'frames' => 900, 'stats' => array_reverse(self::FORGED, true) + ['n' => 4]]);

        app()->call([new VerifyRunReplay($run->id), 'handle']);

        $this->assertSame($points, $this->points());
        $this->assertSame(0, RunFlag::query()->count());
    }

    public function test_the_stats_of_a_game_with_unreliable_replays_are_left_alone(): void
    {
        $this->setSettings(AntiCheatSettings::class, ['verifier_untrusted_games' => ['bactery']]);
        $run = $this->countedRun(self::FORGED);
        $points = $this->points();
        $this->verifying(['ok' => true, 'score' => 100, 'frames' => 900, 'stats' => self::HONEST]);

        app()->call([new VerifyRunReplay($run->id), 'handle']);

        $this->assertSame($points, $this->points());
    }

    public function test_the_stats_of_a_run_that_did_not_count_are_left_alone(): void
    {
        $run = Run::factory()->for($this->game)->for($this->user)->create(['score' => 100, 'score_details' => self::FORGED, 'replay' => ReplayHeaderTest::replay(1 | 64)]);
        $this->verifying(['ok' => true, 'score' => 100, 'frames' => 900, 'stats' => self::HONEST]);

        app()->call([new VerifyRunReplay($run->id), 'handle']);

        $this->assertSame(self::FORGED, $run->fresh()->score_details + self::FORGED);
        $this->assertSame(0, RunFlag::query()->count());
    }

    public function test_the_runs_that_did_not_count_are_caught_up_since_a_date(): void
    {
        $this->countedRun(self::HONEST);
        $old = Run::factory()->for($this->game)->for($this->user)->create(['score_details' => self::FORGED, 'completed_at' => now()->subMonth()]);
        $missed = Run::factory()->for($this->game)->for($this->user)->create(['score_details' => self::HONEST, 'completed_at' => now()->subHour()]);
        Run::factory()->for($this->game)->for($this->user)->create(['score_details' => self::FORGED, 'completed_at' => now()->subHour(), 'is_cheat' => true]);

        $this->artisan('kado:achievements:catch-up')->assertFailed();
        $this->artisan('kado:achievements:catch-up', ['--since' => now()->subDay()->toDateString(), '--dry-run' => true])->assertSuccessful();
        $this->assertSame(1, AchievementEvent::query()->count());

        $this->artisan('kado:achievements:catch-up', ['--since' => now()->subDay()->toDateString()])->assertSuccessful();

        $this->assertSame(2, AchievementEvent::query()->count());
        $this->assertTrue(AchievementEvent::query()->where('source_id', $missed->id)->exists());
        $this->assertFalse(AchievementEvent::query()->where('source_id', $old->id)->exists());
        $this->assertSame(10, $this->progress('total_stars')->current_value);
    }
}
