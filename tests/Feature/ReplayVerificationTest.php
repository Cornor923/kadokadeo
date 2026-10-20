<?php

namespace Tests\Feature;

use App\Enums\RunFlagRule;
use App\Enums\RunVerification;
use App\Jobs\VerifyRunReplay;
use App\Models\ReplayVerification;
use App\Models\Run;
use App\Models\RunFlag;
use App\Models\User;
use App\Services\ReplayVerifier;
use App\Services\RunService;
use App\Settings\AntiCheatSettings;
use App\Support\GameBuilds\GameBuildArchive;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use Spatie\DiscordAlerts\Jobs\SendToDiscordChannelJob;
use Tests\TestCase;
use Tests\Unit\ReplayHeaderTest;

class ReplayVerificationTest extends TestCase
{
    use RefreshDatabase;

    // the verifier gives this result instead of playing the replay in Chrome
    private function fakeVerifier(array $result): void
    {
        $this->app->instance(ReplayVerifier::class, new class(app(GameBuildArchive::class), $result) extends ReplayVerifier
        {
            public function __construct(GameBuildArchive $archive, private array $result)
            {
                parent::__construct($archive);
            }

            public function verify(Run $run): array
            {
                return $this->result;
            }
        });
    }

    // a finished run rewarded with 5 kadopoints by its contract
    private function rewardedRun(int $score): Run
    {
        $user = User::factory()->create(['kado_points' => 5]);
        $run = Run::factory()->for($user)->create(['score' => $score, 'replay' => ReplayHeaderTest::replay(1 | 64), 'contract_score' => 10, 'contract_points' => 5]);
        $user->userPoints()->create(['period_id' => $run->period_id, 'delta' => 5, 'reason' => 'contract completed', 'source_type' => Run::class, 'source_id' => $run->id]);

        return $run;
    }

    private function verify(Run $run): Run
    {
        app()->call([new VerifyRunReplay($run->id), 'handle']);

        return $run->fresh();
    }

    public function test_a_replay_ending_with_the_sent_score_is_verified(): void
    {
        $this->fakeVerifier(['ok' => true, 'score' => 120, 'frames' => 900]);
        $run = $this->verify($this->rewardedRun(120));

        $this->assertSame(RunVerification::VERIFIED, $run->verification);
        $this->assertFalse($run->is_cheat);
        $this->assertSame(5, $run->user->kado_points);
    }

    public function test_a_forged_score_is_flagged_and_its_contract_points_taken_back_once(): void
    {
        $this->fakeVerifier(['ok' => true, 'score' => 20, 'frames' => 900]);
        $run = $this->verify($this->rewardedRun(99999));

        $this->assertSame(RunVerification::MISMATCH, $run->verification);
        $this->assertTrue($run->is_cheat);
        $this->assertSame(0, $run->user->fresh()->kado_points);

        app(RunService::class)->flagAsCheat($run);
        $this->assertSame(0, $run->user->fresh()->kado_points);
    }

    public function test_a_different_score_on_a_game_with_unreliable_replays_is_only_reported(): void
    {
        $this->fakeVerifier(['ok' => true, 'score' => 20, 'frames' => 900]);
        $run = $this->rewardedRun(99999);
        $this->setSettings(AntiCheatSettings::class, ['verifier_untrusted_games' => [$run->game->game_key]]);

        $run = $this->verify($run);

        $this->assertSame(RunVerification::MISMATCH, $run->verification);
        $this->assertFalse($run->is_cheat);
    }

    public function test_a_finished_run_without_replay_is_flagged(): void
    {
        $run = $this->rewardedRun(500);
        $run->update(['replay' => null]);

        $run = $this->verify($run);

        $this->assertSame(RunVerification::NO_REPLAY, $run->verification);
        $this->assertTrue($run->is_cheat);
    }

    public function test_a_replay_the_game_cannot_read_is_flagged(): void
    {
        $run = $this->rewardedRun(500);
        $run->update(['replay' => '936 bytes']);

        $run = $this->verify($run);

        $this->assertSame(RunVerification::NO_REPLAY, $run->verification);
        $this->assertTrue($run->is_cheat);
    }

    public function test_a_replay_the_verifier_cannot_play_goes_to_the_suspicious_runs(): void
    {
        $this->fakeVerifier(['ok' => false, 'error' => 'the game crashed']);
        $run = $this->verify($this->rewardedRun(120));

        $this->assertSame(RunVerification::FAILED, $run->verification);
        // not sanctioned: an admin decides
        $this->assertFalse($run->is_cheat);
        $flag = RunFlag::where('run_id', $run->id)->sole();
        $this->assertSame(RunFlagRule::REPLAY_UNVERIFIABLE, $flag->rule);
        $this->assertSame('the game crashed', $flag->details['error']);
    }

    public function test_only_the_runs_that_count_are_verified_when_the_verifier_is_on(): void
    {
        $verifier = app(ReplayVerifier::class);
        $run = Run::factory()->make(['score' => 50, 'contract_score' => 0]);

        $this->setSettings(AntiCheatSettings::class, ['verifier_enabled' => false]);
        $this->assertFalse($verifier->shouldVerify($run, 10));

        $this->setSettings(AntiCheatSettings::class, ['verifier_enabled' => true]);
        $this->assertTrue($verifier->shouldVerify($run, 10));
        $this->assertFalse($verifier->shouldVerify($run, 80));
        $run->contract_score = 40;
        $this->assertTrue($verifier->shouldVerify($run, 80));
    }

    public function test_the_analysis_of_the_moves_is_kept_and_a_suspicious_one_flagged(): void
    {
        $this->setSettings(AntiCheatSettings::class, ['analysis_flag' => true]);
        $analysis = ['analyzer' => 'binary', 'version' => 1, 'metrics' => ['decisions' => 40, 'optimalRate' => 0.95], 'suspicious' => true, 'reasons' => ['best move 95 % of the time']];
        $this->fakeVerifier(['ok' => true, 'score' => 120, 'frames' => 900, 'analysis' => $analysis]);
        $run = $this->verify($this->rewardedRun(120));

        $this->assertSame(RunVerification::VERIFIED, $run->verification);
        $this->assertFalse($run->is_cheat);
        $this->assertSame($analysis, ReplayVerification::first()->analysis);
        $this->assertSame([\App\Enums\RunFlagRule::GAME_ANALYSIS], $run->flags->pluck('rule')->all());
    }

    public function test_each_verification_is_recorded_with_its_scores(): void
    {
        $this->fakeVerifier(['ok' => true, 'score' => 20, 'frames' => 900]);
        $run = $this->verify($this->rewardedRun(99999));
        $this->fakeVerifier(['ok' => false, 'error' => 'the game crashed']);
        $this->verify($run);

        $verifications = ReplayVerification::orderBy('id')->get();
        $this->assertCount(2, $verifications);
        $this->assertSame(RunVerification::MISMATCH, $verifications[0]->status);
        $this->assertSame([99999, 20, 900], [$verifications[0]->score, $verifications[0]->replay_score, $verifications[0]->frames]);
        $this->assertNotNull($verifications[0]->duration_ms);
        $this->assertSame(RunVerification::FAILED, $verifications[1]->status);
        $this->assertSame('the game crashed', $verifications[1]->error);
    }

    public function test_the_same_failure_of_the_verifier_is_sent_on_discord_once(): void
    {
        Bus::fake([SendToDiscordChannelJob::class]);
        config(['discord-alerts.webhook_urls.default' => 'https://discord.test/webhook']);

        // the same cause: only the numbers and the temporary paths change
        foreach (['the browser did not start: port 41015', 'the browser did not start: port 39877'] as $error) {
            $this->fakeVerifier(['ok' => false, 'error' => $error]);
            $this->verify($this->rewardedRun(120));
        }
        Bus::assertDispatchedTimes(SendToDiscordChannelJob::class, 1);

        $this->fakeVerifier(['ok' => false, 'error' => 'the game crashed']);
        $this->verify($this->rewardedRun(120));
        Bus::assertDispatchedTimes(SendToDiscordChannelJob::class, 2);

        // a cheat is always sent
        $this->fakeVerifier(['ok' => true, 'score' => 20, 'frames' => 900]);
        $this->verify($this->rewardedRun(99999));
        $this->verify($this->rewardedRun(99999));
        Bus::assertDispatchedTimes(SendToDiscordChannelJob::class, 4);
    }

    public function test_only_the_old_verified_replays_are_pruned(): void
    {
        $run = $this->rewardedRun(120);
        $old = now()->subDays(ReplayVerification::KEEP_VERIFIED_DAYS + 1);
        foreach ([RunVerification::VERIFIED, RunVerification::MISMATCH, RunVerification::FAILED] as $status) {
            ReplayVerification::create(['run_id' => $run->id, 'game_id' => $run->game_id, 'status' => $status, 'score' => 120])
                ->forceFill(['created_at' => $old])->save();
        }
        ReplayVerification::create(['run_id' => $run->id, 'game_id' => $run->game_id, 'status' => RunVerification::VERIFIED, 'score' => 120]);

        $this->artisan('model:prune', ['--model' => [ReplayVerification::class]]);

        $this->assertEqualsCanonicalizing(
            [RunVerification::MISMATCH, RunVerification::FAILED, RunVerification::VERIFIED],
            ReplayVerification::pluck('status')->all(),
        );
    }

    public function test_the_replay_player_of_the_admin_panel_is_for_the_admins_only(): void
    {
        $run = $this->rewardedRun(120);
        $url = route('filament.admin.runs.replay', $run->id);
        $admin = User::factory()->create(['is_admin' => true]);

        $this->actingAs(User::factory()->create())->get($url)->assertForbidden();
        // no bundle for the game of the factory
        $this->actingAs($admin)->get($url)->assertOk()->assertSee('pas de replay');

        // played by the version of the game it was recorded with
        $this->mock(GameBuildArchive::class)->shouldReceive('gamedataFor')
            ->andReturn(['file' => '/gamesdata/builds/x/abc.js', 'url' => '/gamesdata/builds/x/abc.js', 'hash' => 'abc', 'asset_base' => '/assets/x']);
        $this->actingAs($admin)->get($url)
            ->assertOk()
            ->assertSee('id="replay-data"', false)
            ->assertSee('\/gamesdata\/builds\/x\/abc.js', false)
            ->assertSee($run->game->pascal_name);
    }
}
