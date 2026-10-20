<?php

namespace Tests\Feature;

use App\Enums\RunVerification;
use App\Jobs\VerifyRunReplay;
use App\Models\Game;
use App\Models\GamePeriodStar;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use App\Services\AchievementService;
use App\Services\RunService;
use App\Settings\AntiCheatSettings;
use App\Settings\ReplaySettings;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Exceptions;
use Illuminate\Support\Facades\Queue;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;
use Tests\Unit\ReplayHeaderTest;

class RunEndTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Same encryption as the game client (KadoEndRun): AES-128-CTR payload, AES key encrypted with the RSA public key.
     */
    private function encryptRun(array $request): array
    {
        $json = json_encode($request);
        $aesKey = random_bytes(16);
        $iv = random_bytes(16);
        $cipher = openssl_encrypt($json, 'aes-128-ctr', $aesKey, OPENSSL_RAW_DATA, $iv);
        openssl_public_encrypt(base64_encode($aesKey), $encryptedKey, app(RunService::class)->getPublicKey());

        return [
            'payload' => base64_encode($iv.$cipher),
            'key' => base64_encode($encryptedKey),
            'sign' => base64_encode(hash_hmac('sha256', $json, $aesKey, true)),
        ];
    }

    public function test_it_serves_the_current_public_key_without_cache(): void
    {
        $response = $this->getJson('/api/runs/public-key')->assertOk();

        $this->assertSame(app(RunService::class)->getPublicKey(), $response->json('data.public_key'));
        $this->assertStringContainsString('no-store', $response->headers->get('Cache-Control'));
    }

    public function test_a_run_sent_twice_is_only_rewarded_once(): void
    {
        $user = User::factory()->create(['kado_points' => 0]);
        $game = Game::factory()->create();
        $run = Run::factory()->for($game)->for($user)->create([
            'score' => 0,
            'completed_at' => null,
            'contract_score' => 100,
            'contract_points' => 5,
        ]);
        Sanctum::actingAs($user);

        $body = $this->encryptRun([
            'run_id' => $run->id,
            'score' => 150,
            'timestamp' => now()->timestamp,
            'replay' => null,
            'data' => [],
            'ac' => 0,
        ]);

        $this->postJson("/api/runs/{$run->id}/finish", $body)->assertOk();
        $this->postJson("/api/runs/{$run->id}/finish", $body)->assertStatus(409);

        $this->assertSame(150, $run->fresh()->score);
        $this->assertSame(5, $user->fresh()->kado_points);
    }

    public function test_only_the_player_of_a_run_finishes_it(): void
    {
        $run = Run::factory()->create(['score' => 0, 'completed_at' => null]);
        Sanctum::actingAs(User::factory()->create());

        $this->postJson("/api/runs/{$run->id}/finish", $this->encryptRun([
            'run_id' => $run->id,
            'score' => 150,
            'timestamp' => now()->timestamp,
            'replay' => null,
            'data' => [],
            'ac' => 0,
        ]))->assertNotFound();

        $this->assertNull($run->fresh()->completed_at);
    }

    public function test_the_players_to_beat_are_the_players_with_a_run_above_the_score(): void
    {
        $game = Game::factory()->create();
        $period = Period::factory()->create();
        $inPeriod = fn () => Run::factory()->for($game)->state(['period_id' => $period->id]);
        // a player above with two runs, a player above, a player below, a cheated run above, another period
        $above = User::factory()->create();
        $inPeriod()->for($above)->create(['score' => 50]);
        $inPeriod()->for($above)->create(['score' => 60]);
        $inPeriod()->create(['score' => 30]);
        $inPeriod()->create(['score' => 5]);
        $inPeriod()->create(['score' => 99, 'is_cheat' => true]);
        Run::factory()->for($game)->create(['score' => 99]);
        $run = $inPeriod()->create(['score' => null, 'completed_at' => null]);

        Sanctum::actingAs($run->user);
        $this->postJson("/api/runs/{$run->id}/finish", $this->encryptRun([
            'run_id' => $run->id,
            'score' => 10,
            'timestamp' => now()->timestamp,
            'replay' => null,
            'data' => [],
            'ac' => 0,
        ]))->assertOk()->assertJsonPath('data.people_to_beat', 2);
    }

    public function test_a_star_reached_by_two_runs_is_counted_once(): void
    {
        $user = User::factory()->create();
        $game = Game::factory()->create(['stars' => [10, 20, 30, 40]]);
        $period = Period::factory()->create();
        $runs = Run::factory()->count(2)->for($user)->for($game)->create(['period_id' => $period->id, 'score' => 25]);

        // (two runs finished at once: each one sees no star yet)
        $runs->each(fn (Run $run) => app(RunService::class)->rewardStars($run));

        $this->assertSame(2, GamePeriodStar::where('user_id', $user->id)->count());
        $stars = $user->stars()->where('period_id', $period->id)->sole();
        $this->assertSame([1, 1, 0, 0], [$stars->green_stars, $stars->orange_stars, $stars->red_stars, $stars->purple_stars]);
    }

    public function test_the_promotions_are_computed_again_only_after_a_new_best_score(): void
    {
        $user = User::factory()->create();
        $game = Game::factory()->create();
        $period = Period::factory()->create();
        Run::factory()->for($user)->for($game)->create(['period_id' => $period->id, 'score' => 100]);
        $key = "promotion_scores_{$game->id}_{$period->id}";
        $finish = function (int $score) use ($user, $game, $period) {
            $run = Run::factory()->for($user)->for($game)->create(['period_id' => $period->id, 'score' => null, 'completed_at' => null]);
            Sanctum::actingAs($user);
            $this->postJson("/api/runs/{$run->id}/finish", $this->encryptRun([
                'run_id' => $run->id,
                'score' => $score,
                'timestamp' => now()->timestamp,
                'replay' => null,
                'data' => [],
                'ac' => 0,
            ]))->assertOk();
        };

        cache()->put($key, 'cached');
        $finish(50);
        $this->assertSame('cached', cache()->get($key));

        $finish(150);
        $this->assertNull(cache()->get($key));
    }

    private function finishWithReplay(Run $run, string $replay, int $antiCheat = 0): Run
    {
        Sanctum::actingAs($run->user);
        $this->postJson("/api/runs/{$run->id}/finish", $this->encryptRun([
            'run_id' => $run->id,
            'score' => 10,
            'timestamp' => now()->timestamp,
            'replay' => $replay,
            'data' => [],
            'ac' => $antiCheat,
        ]))->assertOk();

        return $run->fresh();
    }

    public function test_the_hard_detections_of_the_game_mark_the_run_as_cheated_the_soft_ones_do_not(): void
    {
        $pending = fn () => Run::factory()->create(['score' => 0, 'completed_at' => null]);

        // code of the game replaced
        $run = $this->finishWithReplay($pending(), ReplayHeaderTest::BINARY_V4, 0x2 | 0x10);
        $this->assertTrue($run->is_cheat);
        $this->assertSame(0x12, $run->anticheat_flags);

        // a display object added by a script: for the review only
        $run = $this->finishWithReplay($pending(), ReplayHeaderTest::BINARY_V4, 0x10);
        $this->assertFalse($run->is_cheat);
        $this->assertSame(0x10, $run->anticheat_flags);
        $this->assertSame(421, $run->replay_frames);

        // the functions of the browser replaced, the inputs made by a script: ignored, but kept on the run
        $run = $this->finishWithReplay($pending(), ReplayHeaderTest::BINARY_V4, 0x40 | 0x80);
        $this->assertFalse($run->is_cheat);
        $this->assertSame(0xC0, $run->anticheat_flags);

        // ignored bits win over a strict setting
        $this->setSettings(AntiCheatSettings::class, ['soft_bits' => 0]);
        $this->assertFalse($this->finishWithReplay($pending(), ReplayHeaderTest::BINARY_V4, 0x80)->is_cheat);

        // no soft bit: any other bit marks the run
        $this->setSettings(AntiCheatSettings::class, ['soft_bits' => 0]);
        $this->assertTrue($this->finishWithReplay($pending(), ReplayHeaderTest::BINARY_V4, 0x10)->is_cheat);
    }

    public function test_a_replay_without_the_stirred_draws_is_flagged_outside_the_daily_game(): void
    {
        $this->setSettings(AntiCheatSettings::class, ['require_rng_stir' => true]);
        $pending = fn () => Run::factory()->create(['score' => 0, 'completed_at' => null]);

        $this->assertTrue($this->finishWithReplay($pending(), ReplayHeaderTest::replay(1))->is_cheat);
        $this->assertFalse($this->finishWithReplay($pending(), ReplayHeaderTest::replay(1 | 64))->is_cheat);
    }

    public function test_the_daily_game_is_not_stirred(): void
    {
        $this->setSettings(AntiCheatSettings::class, ['require_rng_stir' => true]);
        $game = Game::factory()->create();
        $daily = \App\Models\DailyGame::create(['day' => today(), 'game_id' => $game->id, 'seed' => 'daily', 'contract_score' => 0, 'contract_points' => 0]);
        $run = Run::factory()->for($game)->create(['score' => 0, 'completed_at' => null, 'daily_game_id' => $daily->id]);

        $this->assertFalse($this->finishWithReplay($run, ReplayHeaderTest::replay(1))->is_cheat);
    }

    public function test_a_replay_without_the_time_of_the_inputs_is_flagged_once_it_is_required(): void
    {
        $this->setSettings(AntiCheatSettings::class, ['require_rng_stir' => true, 'require_input_phases' => true]);
        $pending = fn () => Run::factory()->create(['score' => 0, 'completed_at' => null]);

        $this->assertTrue($this->finishWithReplay($pending(), ReplayHeaderTest::replay(1 | 64))->is_cheat);
        $this->assertTrue($this->finishWithReplay($pending(), ReplayHeaderTest::replay(1 | 64 | 128, 3))->is_cheat);
        $this->assertFalse($this->finishWithReplay($pending(), ReplayHeaderTest::replay(1 | 64 | 128, 4))->is_cheat);

        $this->setSettings(AntiCheatSettings::class, ['require_input_phases' => false]);
        $this->assertFalse($this->finishWithReplay($pending(), ReplayHeaderTest::replay(1 | 64))->is_cheat);
    }

    public function test_replays_without_the_stir_are_accepted_until_it_is_required(): void
    {
        $this->setSettings(AntiCheatSettings::class, ['require_rng_stir' => false]);
        $run = Run::factory()->create(['score' => 0, 'completed_at' => null]);

        $this->assertFalse($this->finishWithReplay($run, ReplayHeaderTest::replay(1))->is_cheat);
    }

    public function test_the_end_of_a_new_best_run_queues_its_verification(): void
    {
        Queue::fake();
        $this->setSettings(AntiCheatSettings::class, ['verifier_enabled' => true]);

        $run = $this->finishWithReplay(Run::factory()->create(['score' => 0, 'completed_at' => null]), ReplayHeaderTest::replay(1 | 64));

        Queue::assertPushed(VerifyRunReplay::class, fn ($job) => $job->runId === $run->id);
        $this->assertSame(RunVerification::PENDING, $run->verification);
    }

    public function test_a_replay_above_the_size_limit_is_refused(): void
    {
        $this->setSettings(ReplaySettings::class, ['max_length' => 100]);
        $run = Run::factory()->create(['score' => 0, 'completed_at' => null]);
        Sanctum::actingAs($run->user);
        $finish = fn (string $replay) => $this->postJson("/api/runs/{$run->id}/finish", $this->encryptRun([
            'run_id' => $run->id,
            'score' => 10,
            'timestamp' => now()->timestamp,
            'replay' => $replay,
            'data' => [],
            'ac' => 0,
        ]));

        $finish(str_repeat('A', 101))->assertStatus(400);
        $this->assertNull($run->fresh()->completed_at);
        $finish(str_repeat('A', 100))->assertOk();
    }

    public function test_a_payload_above_the_size_limit_is_refused_before_it_is_decrypted(): void
    {
        $this->setSettings(ReplaySettings::class, ['max_length' => 0]);
        $run = Run::factory()->create(['score' => 0, 'completed_at' => null]);
        Sanctum::actingAs($run->user);

        $this->postJson("/api/runs/{$run->id}/finish", ['payload' => str_repeat('A', 1_000_001), 'key' => 'key', 'sign' => 'sign'])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['payload']);
    }

    public function test_the_ends_of_runs_are_throttled_apart_from_the_begins(): void
    {
        $run = Run::factory()->create(['score' => 0, 'completed_at' => null]);
        Sanctum::actingAs($run->user);
        $body = ['payload' => 'bad', 'key' => 'bad', 'sign' => 'bad'];

        for ($i = 0; $i < 30; $i++) {
            $this->postJson("/api/runs/{$run->id}/finish", $body)->assertStatus(400);
        }
        $this->postJson("/api/runs/{$run->id}/finish", $body)->assertStatus(429);
        // (refused by GamePolicy::view, the game has no bundle in the tests: not 429)
        $this->postJson("/api/runs/games/{$run->game_id}")->assertForbidden();
    }

    // a payload the server can't read is the fault of the client (400, not reported); an error after it is reported, the
    // game still gets its 400
    public function test_the_unexpected_errors_of_the_end_of_a_run_are_reported(): void
    {
        Exceptions::fake();
        $run = Run::factory()->create(['score' => 0, 'completed_at' => null]);
        Sanctum::actingAs($run->user);
        $body = $this->encryptRun([
            'run_id' => $run->id,
            'score' => 10,
            'timestamp' => now()->timestamp,
            'replay' => null,
            'data' => [],
            'ac' => 0,
        ]);

        $this->postJson("/api/runs/{$run->id}/finish", [...$body, 'sign' => base64_encode('forged')])
            ->assertStatus(400)
            ->assertJsonPath('message', 'Bad request.');
        Exceptions::assertNothingReported();

        $this->mock(AchievementService::class)->shouldReceive('handleGameRunCompleted')->andThrow(new \RuntimeException('boom'));
        $this->postJson("/api/runs/{$run->id}/finish", $body)
            ->assertStatus(400)
            ->assertJsonPath('message', 'Bad request.');
        Exceptions::assertReported(fn (\RuntimeException $e) => $e->getMessage() === 'boom');
    }
}
