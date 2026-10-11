<?php

namespace Tests\Feature;

use App\Models\Game;
use App\Models\GameBuild;
use App\Models\Run;
use App\Models\User;
use App\Support\GameBuilds\BundleDelta;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Old versions of the games kept for their replays (fixtures: tests/Fixtures/game-builds, made by its make.mjs with
 * the delta of the build: a current bundle and two old versions of the game "testgame").
 */
class GameBuildsTest extends TestCase
{
    use RefreshDatabase;

    private const CURRENT = 'bee4b73f901e';

    private const OLD = '596f189240bb';

    private const LEGACY = 'f8df6af08735';

    private string $fixtures;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixtures = base_path('tests/Fixtures/game-builds');
        $this->app->usePublicPath($this->fixtures.'/public');
        config(['kado.game_builds.path' => $this->fixtures.'/storage', 'kado.game_builds.enabled' => true]);
    }

    private function game(): Game
    {
        return Game::factory()->create(['name' => 'Testgame']);
    }

    public function test_an_old_version_is_rebuilt_from_the_current_bundle(): void
    {
        $response = $this->get('/gamesdata/builds/testgame/'.self::OLD.'.js');

        $response->assertOk();
        $this->assertSame(file_get_contents($this->fixtures.'/expected/'.self::OLD.'.js'), $response->getContent());
        $this->assertSame(self::OLD, BundleDelta::hash($response->getContent()));
        $this->assertStringContainsString('immutable', $response->headers->get('Cache-Control'));
        $this->assertStringContainsString('javascript', $response->headers->get('Content-Type'));
    }

    public function test_an_unknown_version_is_not_found(): void
    {
        $this->get('/gamesdata/builds/testgame/0123456789ab.js')->assertNotFound();
        $this->get('/gamesdata/builds/othergame/'.self::OLD.'.js')->assertNotFound();
    }

    public function test_the_copy_of_the_archive_is_used_when_public_gamesdata_is_gone(): void
    {
        $this->app->usePublicPath(sys_get_temp_dir().'/kado-no-public-'.uniqid());

        $response = $this->get('/gamesdata/builds/testgame/'.self::LEGACY.'.js');

        $response->assertOk();
        $this->assertSame(self::LEGACY, BundleDelta::hash($response->getContent()));
    }

    public function test_an_old_version_is_served_while_a_build_replaces_the_current_bundle(): void
    {
        // the new bundle and its deltas are written, index.json (and the copy of the bundle) not yet
        $storage = sys_get_temp_dir().'/kado-game-builds-'.uniqid();
        mkdir($storage.'/testgame/bundles', 0777, true);
        copy($this->fixtures.'/storage/index.json', $storage.'/index.json');
        foreach (glob($this->fixtures.'/storage/testgame/bundles/*.kdd') as $file) {
            copy($file, $storage.'/testgame/bundles/'.basename($file));
        }
        config(['kado.game_builds.path' => $storage]);
        $this->app->usePublicPath($this->fixtures.'/building/public');

        $response = $this->get('/gamesdata/builds/testgame/'.self::OLD.'.js');

        $response->assertOk();
        $this->assertSame(self::OLD, BundleDelta::hash($response->getContent()));
        // the legacy version has no delta for the new bundle yet: back in a moment
        $this->get('/gamesdata/builds/testgame/'.self::LEGACY.'.js')->assertStatus(503);
    }

    public function test_a_run_remembers_the_version_of_the_game_it_is_played_with(): void
    {
        $game = $this->game();
        Sanctum::actingAs(User::factory()->create());

        foreach ([self::CURRENT => true, self::OLD => true, '0123456789ab' => false, 'not-a-hash' => null] as $hash => $kept) {
            $response = $this->postJson("/api/runs/games/{$game->id}", ['build' => $hash]);
            if ($kept === null) {
                $response->assertUnprocessable();

                continue;
            }
            $response->assertSuccessful();
            $run = Run::find($response->json('data.run_id'));
            $this->assertSame($kept ? $hash : null, $run->gameBuild?->hash, "build {$hash}");
        }
        // one row per version of the game
        $this->assertSame(2, GameBuild::count());

        $response = $this->postJson("/api/runs/games/{$game->id}");
        $response->assertSuccessful();
        $this->assertNull(Run::find($response->json('data.run_id'))->game_build_id);
    }

    public function test_a_replay_is_played_by_the_version_it_was_recorded_with(): void
    {
        $game = $this->game();
        Sanctum::actingAs(User::factory()->create());
        $build = fn (string $hash) => GameBuild::create(['game_id' => $game->id, 'hash' => $hash])->id;
        $replay = fn (?int $buildId) => Run::factory()->for($game)->create(['replay' => 'replay data', 'game_build_id' => $buildId]);

        $old = $this->getJson('/api/runs/'.$replay($build(self::OLD))->id)->assertOk()->json('data.gamedata');
        $this->assertSame('/gamesdata/builds/testgame/'.self::OLD.'.js', $old['url']);
        $this->assertSame('/gamesdata/builds/testgame/'.self::OLD.'/', $old['asset_base']);
        $this->assertTrue($old['module']);

        $current = $this->getJson('/api/runs/'.$replay($build(self::CURRENT))->id)->assertOk()->json('data.gamedata');
        $this->assertSame('/gamesdata/testgame.js?v='.self::CURRENT, $current['url']);
        $this->assertNull($current['asset_base']);
        $this->assertTrue($current['module']);

        // recorded before the archive: the bundle that was there when the archive began
        $legacy = $this->getJson('/api/runs/'.$replay(null)->id)->assertOk()->json('data.gamedata');
        $this->assertSame('/gamesdata/builds/testgame/'.self::LEGACY.'.js', $legacy['url']);
        $this->assertNull($legacy['asset_base']);
        // built before the ES modules: a classic script
        $this->assertFalse($legacy['module']);
    }

    public function test_the_versions_used_by_replays_are_listed_for_the_build(): void
    {
        $storage = sys_get_temp_dir().'/kado-game-builds-'.uniqid();
        config(['kado.game_builds.path' => $storage]);
        $game = $this->game();
        $other = Game::factory()->create(['name' => 'Other game']);
        $used = GameBuild::create(['game_id' => $game->id, 'hash' => self::OLD]);
        $unused = GameBuild::create(['game_id' => $game->id, 'hash' => self::CURRENT]);
        Run::factory()->for($game)->create(['replay' => 'replay data', 'game_build_id' => $used->id]);
        Run::factory()->for($game)->create(['replay' => null, 'game_build_id' => $unused->id]);
        Run::factory()->for($other)->create(['replay' => 'replay data', 'game_build_id' => null]);

        $this->artisan('kado:game-builds:keep')->assertSuccessful();

        $keep = json_decode(file_get_contents($storage.'/keep.json'), true);
        $this->assertSame(['testgame' => [self::OLD]], $keep['games']);
        $this->assertSame(['othergame' => true], $keep['legacy']);
        $this->assertNotEmpty($keep['generatedAt']);
    }
}
