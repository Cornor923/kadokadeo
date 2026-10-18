<?php

namespace Tests\Feature;

use App\Enums\ClanAttackStatus;
use App\Models\Clan;
use App\Models\ClanAttack;
use App\Models\ClanPeriodScore;
use App\Models\Game;
use App\Models\Period;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DebugClanTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_debug_tools_are_off_without_kado_debug_tools(): void
    {
        config(['kado.debug_tools' => false]);
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/debug/clans')->assertNotFound();
        $this->postJson('/api/debug/clans/time', ['hours' => 12])->assertNotFound();
    }

    public function test_attacks_defenses_and_time_with_the_debug_tools(): void
    {
        config(['kado.debug_tools' => true]);
        $period = Period::factory()->create(['start_at' => now()->subDay(), 'end_at' => now()->addDays(12)]);
        $me = User::factory()->create();
        $mine = Clan::factory()->withLeader($me)->create();
        $other = Clan::factory()->withLeader()->create();
        $game = Game::factory()->create();
        Sanctum::actingAs($me);

        $this->getJson('/api/debug/clans')->assertOk()->assertJsonPath('data.my_clan_id', $mine->id);

        // an attack of the other clan against mine, repelled by me
        $this->postJson('/api/debug/clans/attack', ['attacker_clan_id' => $other->id, 'defender_clan_id' => $mine->id, 'game_id' => $game->id, 'score' => 100])->assertOk();
        $attack = ClanAttack::query()->sole();
        $this->postJson("/api/debug/clans/attacks/{$attack->id}/defend", ['score' => 101])->assertOk();
        $this->assertSame(ClanAttackStatus::REPELLED, $attack->fresh()->status);

        // my attack, won when 12 hours went by
        $this->postJson('/api/debug/clans/attack', ['attacker_clan_id' => $mine->id, 'defender_clan_id' => $other->id, 'game_id' => $game->id, 'score' => 100])->assertOk();
        $this->postJson('/api/debug/clans/time', ['hours' => 13])->assertOk();
        $this->assertSame(ClanAttackStatus::WON, ClanAttack::query()->latest('id')->first()->status);
        $this->assertGreaterThan(0, ClanPeriodScore::query()->where('clan_id', $mine->id)->value('war_score'));

        // the end of the period: a new one, the scores at 0
        $this->postJson('/api/debug/clans/end-period')->assertOk();
        $this->assertNotNull(ClanPeriodScore::query()->where('period_id', $period->id)->where('clan_id', $mine->id)->value('closed_at'));
        $this->travel(2)->seconds();
        $this->getJson("/api/clans/{$mine->id}")->assertOk()->assertJsonPath('data.stats.war_score', 0);
    }
}
