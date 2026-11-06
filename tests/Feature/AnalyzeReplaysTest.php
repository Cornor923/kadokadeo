<?php

namespace Tests\Feature;

use App\Models\Game;
use App\Models\Run;
use App\Services\ReplayVerifier;
use App\Support\GameBuilds\GameBuildArchive;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use Tests\Unit\ReplayHeaderTest;

class AnalyzeReplaysTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_run_without_a_readable_replay_is_not_played(): void
    {
        $run = Run::factory()->create(['replay' => '936 bytes']);

        $this->assertSame(['ok' => false, 'error' => 'not a replay of the game'], app(ReplayVerifier::class)->verify($run));
    }

    public function test_the_analysis_skips_the_runs_without_a_readable_replay(): void
    {
        $verified = [];
        $this->app->instance(ReplayVerifier::class, new class(app(GameBuildArchive::class), $verified) extends ReplayVerifier
        {
            public function __construct(GameBuildArchive $archive, private array &$verified)
            {
                parent::__construct($archive);
            }

            public function hasAnalyzer(string $key): bool
            {
                return true;
            }

            public function verify(Run $run, array $input = [], bool $currentBundle = false): array
            {
                $this->verified[] = $run->id;

                return ['ok' => true, 'score' => $run->score, 'frames' => 10, 'analysis' => ['analyzer' => 'kaskade2', 'metrics' => ['decisions' => 20, 'optimalRate' => 0.4], 'suspicious' => false, 'reasons' => []]];
            }
        });
        $game = Game::factory()->create(['name' => 'Kaskade 2']);
        $emptied = Run::factory()->for($game)->create(['replay' => '892 bytes', 'completed_at' => now()]);
        $replayed = Run::factory()->for($game)->create(['replay' => ReplayHeaderTest::BINARY_V4, 'completed_at' => now()->subMinute()]);

        $this->artisan('kado:replays:analyze', ['game' => 'kaskade2'])
            ->expectsOutputToContain('1 partie(s) sans replay lisible ignorée(s).')
            ->assertSuccessful();

        $this->assertSame([$replayed->id], $verified);
        $this->assertNotContains($emptied->id, $verified);
    }
}
