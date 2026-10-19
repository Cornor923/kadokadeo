<?php

namespace Tests\Feature;

use App\Models\Clan;
use App\Models\Game;
use App\Models\Period;
use App\Models\User;
use App\Settings\ClanSettings;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

// the clans turned off in the admin (ClanSettings::$enabled, off by default): their routes are refused, the runs take
// no clan action, the admin still manages them
class ClansToggleTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Period::factory()->create(['start_at' => now()->subDay()->startOfDay(), 'end_at' => now()->addDays(12)->endOfDay()]);
    }

    private function setClansEnabled(bool $enabled): void
    {
        $settings = app(ClanSettings::class);
        $settings->enabled = $enabled;
        $settings->save();
    }

    public function test_the_clans_are_off_by_default(): void
    {
        $this->assertFalse(app(ClanSettings::class)->enabled);
    }

    public function test_the_clan_routes_are_refused_while_the_clans_are_off(): void
    {
        $clan = Clan::factory()->withLeader()->create();
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/clans/overview')->assertForbidden()->assertJsonPath('message', 'Les clans seront bientôt disponibles.');
        $this->getJson('/api/clans')->assertForbidden();
        $this->postJson('/api/clans', ['name' => 'Boule de neige'])->assertForbidden();
        $this->getJson("/api/clans/{$clan->id}")->assertForbidden();
        $this->getJson("/api/clans/{$clan->id}/forum/topics")->assertForbidden();
        $this->getJson('/api/debug/clans')->assertForbidden();
        $this->assertSame(1, Clan::count());

        $this->setClansEnabled(true);
        $this->getJson('/api/clans/overview')->assertOk();
    }

    // an attack asked before the clans were turned off: the next run of the game is a normal run
    public function test_a_run_takes_no_clan_action_while_the_clans_are_off(): void
    {
        $this->setClansEnabled(true);
        $game = Game::factory()->create();
        $player = User::factory()->create();
        Clan::factory()->withLeader($player)->create();
        $defender = Clan::factory()->withLeader()->create();
        Sanctum::actingAs($player);
        $this->postJson("/api/clans/{$defender->id}/attacks", ['game_id' => $game->id])->assertCreated();

        $this->setClansEnabled(false);
        $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful()->assertJsonPath('data.clan', null);
        $this->assertDatabaseHas('clan_actions', ['user_id' => $player->id, 'run_id' => null]);
    }

    public function test_the_page_tells_the_front_whether_the_clans_are_on(): void
    {
        $this->setClansEnabled(false);
        $this->get('/games')->assertOk()->assertSee('clans_enabled: false', false);

        $this->setClansEnabled(true);
        $this->get('/games')->assertOk()->assertSee('clans_enabled: true', false);
    }
}
