<?php

namespace Tests\Feature;

use App\Models\Game;
use App\Models\Run;
use App\Services\ReplayVerifier;
use App\Support\GameBuilds\GameBuildArchive;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\File;
use Tests\TestCase;
use Tests\Unit\ReplayHeaderTest;

class CompareReplaysTest extends TestCase
{
    use RefreshDatabase;

    private const KEY = 'comparetest';

    private Game $game;

    /** @var array<string, array<string, mixed>> */
    private array $played = [];

    /** @var list<array{array<string, mixed>, bool}> */
    private array $calls = [];

    protected function setUp(): void
    {
        parent::setUp();
        $this->game = Game::factory()->create(['name' => 'Compare Test']);
        File::ensureDirectoryExists(public_path('gamesdata'));
        File::put($this->bundle(), 'version 1');
        $this->app->instance(ReplayVerifier::class, new class(app(GameBuildArchive::class), $this->played, $this->calls) extends ReplayVerifier
        {
            public function __construct(GameBuildArchive $archive, private array &$played, private array &$calls)
            {
                parent::__construct($archive);
            }

            public function verify(Run $run, array $input = [], bool $currentBundle = false): array
            {
                $this->calls[] = [$input, $currentBundle];

                return $this->played[$run->id] ?? ['ok' => true, 'score' => $run->score, 'frames' => 100, 'stats' => $run->score_details];
            }
        });
    }

    protected function tearDown(): void
    {
        File::delete([$this->bundle(), storage_path('app/replay-compare/'.self::KEY.'.json'), storage_path('app/replay-compare/'.self::KEY.'.compare.json')]);
        parent::tearDown();
    }

    private function bundle(): string
    {
        return public_path('gamesdata/'.self::KEY.'.js');
    }

    private function finishedRun(int $score = 500, array $stats = [1, 2]): Run
    {
        return Run::factory()->for($this->game)->create(['score' => $score, 'score_details' => $stats, 'replay' => ReplayHeaderTest::BINARY_V4, 'completed_at' => now()]);
    }

    private function compare(array $options = [])
    {
        return $this->artisan('kado:replays:compare', ['game' => self::KEY, '--parallel' => 1] + $options);
    }

    public function test_it_needs_a_reference(): void
    {
        $this->finishedRun();

        $this->compare()->expectsOutputToContain('Pas de référence')->assertFailed();
    }

    public function test_the_replays_are_played_by_the_bundle_of_today_with_their_stats_and_without_analysis(): void
    {
        $this->finishedRun();

        $this->compare(['--baseline' => true])->assertSuccessful();

        $this->assertSame([[['stats' => true, 'analysis' => null], true]], $this->calls);
    }

    public function test_the_reference_says_what_the_database_has(): void
    {
        $same = $this->finishedRun();
        $other = $this->finishedRun();
        $this->played[$other->id] = ['ok' => true, 'score' => 501, 'frames' => 100, 'stats' => [1, 2]];

        $this->compare(['--baseline' => true])
            ->expectsOutputToContain('Score de la base retrouvé : 1 / 2.')
            ->assertSuccessful();

        $this->assertArrayHasKey($same->id, json_decode(File::get(storage_path('app/replay-compare/'.self::KEY.'.json')), true)['runs']);
    }

    public function test_the_same_replays_pass_and_a_bundle_not_rebuilt_is_told(): void
    {
        $this->finishedRun();
        $this->compare(['--baseline' => true])->assertSuccessful();

        $this->compare()
            ->expectsOutputToContain('le jeu a-t-il été recompilé')
            ->expectsOutputToContain('1 partie(s) rejouée(s) à l’identique')
            ->assertSuccessful();
    }

    public function test_a_score_or_a_frame_changed_fails(): void
    {
        $score = $this->finishedRun();
        $frames = $this->finishedRun();
        $this->finishedRun();
        $this->compare(['--baseline' => true])->assertSuccessful();
        File::put($this->bundle(), 'version 2');
        $this->played[$score->id] = ['ok' => true, 'score' => 999, 'frames' => 100, 'stats' => [1, 2]];
        $this->played[$frames->id] = ['ok' => true, 'score' => 500, 'frames' => 101, 'stats' => [1, 2]];

        $this->compare()
            ->doesntExpectOutputToContain('recompilé')
            ->expectsOutputToContain('2 partie(s) sur 3 ne se rejouent plus pareil.')
            ->assertFailed();
    }

    public function test_a_replay_that_now_fails_fails(): void
    {
        $run = $this->finishedRun();
        $this->compare(['--baseline' => true])->assertSuccessful();
        $this->played[$run->id] = ['ok' => false, 'error' => 'the game crashed'];

        $this->compare()->expectsOutputToContain('1 partie(s) sur 1 ne se rejouent plus pareil.')->assertFailed();
    }

    public function test_other_stats_only_are_told_without_failing(): void
    {
        $run = $this->finishedRun();
        $this->compare(['--baseline' => true])->assertSuccessful();
        File::put($this->bundle(), 'version 2');
        $this->played[$run->id] = ['ok' => true, 'score' => 500, 'frames' => 100, 'stats' => ['c' => [1, 2]]];

        $this->compare()
            ->expectsOutputToContain('Stats envoyées différentes : 1 partie(s), par exemple [1,2] -> {"c":[1,2]}.')
            ->assertSuccessful();

        $this->assertSame(['c' => [1, 2]], json_decode(File::get(storage_path('app/replay-compare/'.self::KEY.'.compare.json')), true)['runs'][$run->id]['stats']);
    }

    public function test_an_unknown_game_fails(): void
    {
        $this->artisan('kado:replays:compare', ['game' => 'nope'])->assertFailed();
    }
}
