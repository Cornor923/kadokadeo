<?php

namespace Tests\Feature;

use App\Enums\RunVerification;
use App\Jobs\VerifyRunReplay;
use App\Models\Game;
use App\Models\Run;
use App\Models\User;
use App\Services\RunService;
use Illuminate\Foundation\Testing\RefreshDatabase;
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

        // no soft bit: any bit marks the run
        config(['kado.anticheat.soft_bits' => 0]);
        $this->assertTrue($this->finishWithReplay($pending(), ReplayHeaderTest::BINARY_V4, 0x10)->is_cheat);
    }

    public function test_a_replay_without_the_stirred_draws_is_flagged_outside_the_daily_game(): void
    {
        config(['kado.require_rng_stir' => true]);
        $pending = fn () => Run::factory()->create(['score' => 0, 'completed_at' => null]);

        $this->assertTrue($this->finishWithReplay($pending(), ReplayHeaderTest::replay(1))->is_cheat);
        $this->assertFalse($this->finishWithReplay($pending(), ReplayHeaderTest::replay(1 | 64))->is_cheat);
    }

    public function test_the_daily_game_is_not_stirred(): void
    {
        config(['kado.require_rng_stir' => true]);
        $game = Game::factory()->create();
        $daily = \App\Models\DailyGame::create(['day' => today(), 'game_id' => $game->id, 'seed' => 'daily', 'contract_score' => 0, 'contract_points' => 0]);
        $run = Run::factory()->for($game)->create(['score' => 0, 'completed_at' => null, 'daily_game_id' => $daily->id]);

        $this->assertFalse($this->finishWithReplay($run, ReplayHeaderTest::replay(1))->is_cheat);
    }

    public function test_a_replay_without_the_time_of_the_inputs_is_flagged_once_it_is_required(): void
    {
        config(['kado.require_rng_stir' => true, 'kado.require_input_phases' => true]);
        $pending = fn () => Run::factory()->create(['score' => 0, 'completed_at' => null]);

        $this->assertTrue($this->finishWithReplay($pending(), ReplayHeaderTest::replay(1 | 64))->is_cheat);
        $this->assertTrue($this->finishWithReplay($pending(), ReplayHeaderTest::replay(1 | 64 | 128, 3))->is_cheat);
        $this->assertFalse($this->finishWithReplay($pending(), ReplayHeaderTest::replay(1 | 64 | 128, 4))->is_cheat);

        config(['kado.require_input_phases' => false]);
        $this->assertFalse($this->finishWithReplay($pending(), ReplayHeaderTest::replay(1 | 64))->is_cheat);
    }

    public function test_replays_without_the_stir_are_accepted_until_it_is_required(): void
    {
        config(['kado.require_rng_stir' => false]);
        $run = Run::factory()->create(['score' => 0, 'completed_at' => null]);

        $this->assertFalse($this->finishWithReplay($run, ReplayHeaderTest::replay(1))->is_cheat);
    }

    public function test_the_end_of_a_new_best_run_queues_its_verification(): void
    {
        Queue::fake();
        config(['kado.replay_verifier.enabled' => true]);

        $run = $this->finishWithReplay(Run::factory()->create(['score' => 0, 'completed_at' => null]), ReplayHeaderTest::replay(1 | 64));

        Queue::assertPushed(VerifyRunReplay::class, fn ($job) => $job->runId === $run->id);
        $this->assertSame(RunVerification::PENDING, $run->verification);
    }
}
