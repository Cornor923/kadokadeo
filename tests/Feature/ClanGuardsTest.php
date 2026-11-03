<?php

namespace Tests\Feature;

use App\Enums\ClanActionType;
use App\Enums\ClanAttackStatus;
use App\Enums\ClanBonusType;
use App\Exceptions\ClanException;
use App\Models\Clan;
use App\Models\ClanAction;
use App\Models\ClanAttack;
use App\Models\ClanBonus;
use App\Models\ClanPeriodScore;
use App\Models\Game;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use App\Services\ClanMissionService;
use App\Services\ClanRunService;
use App\Services\ClanService;
use App\Services\ClanWarService;
use App\Settings\ClanSettings;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\EnablesClans;
use Tests\TestCase;

// the rules of the clans checked again when they are written (two requests at the same time, a member who left meanwhile):
// PostgreSQL locks the rows, SQLite only runs the checks one after the other
class ClanGuardsTest extends TestCase
{
    use EnablesClans, RefreshDatabase;

    private function period(): Period
    {
        return Period::factory()->create(['start_at' => now()->subDay()->startOfDay(), 'end_at' => now()->addDays(12)->endOfDay()]);
    }

    // a run of the game begun and bound to the clan action asked
    private function beginClanRun(User $user, Game $game, Period $period): Run
    {
        $run = Run::factory()->for($game)->for($user)->for($period)->create(['score' => 0, 'completed_at' => null]);
        app(ClanRunService::class)->bindRun($run);

        return $run;
    }

    public function test_an_option_is_used_once(): void
    {
        ClanSettings::fake(['bonus_chance' => 0]);
        $period = $this->period();
        $leader = User::factory()->create();
        $clan = Clan::factory()->withLeader($leader)->create();
        Game::factory()->count(6)->create();
        $mission = app(ClanMissionService::class)->currentMission($clan);
        $bonus = ClanBonus::query()->create(['clan_id' => $clan->id, 'period_id' => $period->id, 'type' => ClanBonusType::MORE_TIME]);
        // (read by the second request before the first one used it)
        $stale = $bonus->fresh();

        Sanctum::actingAs($leader);
        $this->postJson("/api/clan-bonuses/{$bonus->id}/use")->assertNoContent();
        $this->postJson("/api/clan-bonuses/{$bonus->id}/use")->assertStatus(422)
            ->assertJsonPath('message', 'Cette option a déjà été utilisée.');
        try {
            app(ClanMissionService::class)->useBonus($leader, $stale);
            $this->fail('The option was used twice.');
        } catch (ClanException $e) {
            $this->assertSame('Cette option a déjà été utilisée.', $e->getMessage());
        }
        // the time added once
        $this->assertTrue($mission->expires_at->clone()->addHours(6)->eq($mission->fresh()->expires_at));
    }

    public function test_two_attacks_resolved_against_the_same_clan(): void
    {
        $period = $this->period();
        [$first, $second] = User::factory()->count(2)->create();
        $attackers = Clan::factory()->withLeader($first)->create();
        $attackers->members()->create(['user_id' => $second->id]);
        $defender = Clan::factory()->withLeader()->create();
        ClanPeriodScore::query()->create(['clan_id' => $defender->id, 'period_id' => $period->id, 'war_score' => 15]);
        $game = Game::factory()->create();
        foreach ([$first, $second] as $user) {
            ClanAttack::query()->create([
                'period_id' => $period->id, 'game_id' => $game->id, 'attacker_clan_id' => $attackers->id, 'attacker_user_id' => $user->id,
                'defender_clan_id' => $defender->id, 'score' => 100, 'status' => ClanAttackStatus::ACTIVE, 'expires_at' => now()->subMinute(),
            ]);
        }
        $service = app(ClanService::class);

        $this->assertSame(2, app(ClanWarService::class)->resolveExpired());
        $this->assertSame(0, app(ClanWarService::class)->resolveExpired());

        // the second attack counts with the scores left by the first one
        $firstPoints = $service->attackPoints(0, 15);
        $secondPoints = $service->attackPoints($firstPoints, 15 - $firstPoints);
        $this->assertSame([$firstPoints, $secondPoints], ClanAttack::query()->orderBy('id')->pluck('points')->all());
        $scores = ClanPeriodScore::query()->get()->keyBy('clan_id');
        $this->assertSame($firstPoints + $secondPoints, $scores[$attackers->id]->war_score);
        $this->assertSame(2, (int) $scores[$attackers->id]->attacks_won);
        $this->assertSame(max(0, 15 - $firstPoints - $secondPoints), $scores[$defender->id]->war_score);
        $this->assertSame(2, (int) $scores[$defender->id]->attacks_lost);
    }

    // a leader_id left on a clan he no longer is in (or a player who left during a transfer) does not lead it
    public function test_a_leader_out_of_the_clan_is_not_its_leader(): void
    {
        $this->period();
        $former = User::factory()->create();
        $member = User::factory()->create();
        $clan = Clan::factory()->withLeader($member)->create();
        $clan->update(['leader_id' => $former->id]);
        $service = app(ClanService::class);

        $this->assertNull($service->roleOf($former, $clan));
        Sanctum::actingAs($former);
        $this->getJson("/api/clans/{$clan->id}")->assertOk()->assertJsonPath('data.viewer.can_manage', false);
        $this->deleteJson("/api/clans/{$clan->id}")->assertStatus(422)
            ->assertJsonPath('message', 'Seul le chef de clan peut faire ça.');
        $this->postJson("/api/clans/{$clan->id}/members/{$member->etwin_id}/leader")->assertStatus(422);
        $this->assertModelExists($clan);
        $this->assertSame($former->id, $clan->fresh()->leader_id);
    }

    // left or excluded: his attacks stay with the clan, but he no longer improves nor cancels them, and his clan runs no
    // longer count for it
    public function test_a_member_who_left_no_longer_acts_for_the_clan(): void
    {
        $period = $this->period();
        $leader = User::factory()->create();
        $attacker = User::factory()->create(['clan_attack_games' => 3]);
        $clan = Clan::factory()->withLeader($leader)->create();
        $clan->members()->create(['user_id' => $attacker->id]);
        $defender = Clan::factory()->withLeader()->create();
        [$game, $other] = Game::factory()->count(2)->create();
        $warService = app(ClanWarService::class);

        $warService->startAttack($attacker, $defender, $game);
        $run = $this->beginClanRun($attacker, $game, $period);
        $run->update(['score' => 500, 'completed_at' => now()]);
        app(ClanRunService::class)->handleRunCompleted($run->fresh());
        $attack = ClanAttack::query()->sole();
        // an improvement begun, then another asked and not begun
        $warService->startImprovement($attacker, $attack);
        $begun = $this->beginClanRun($attacker, $game, $period);
        $pending = $warService->startImprovement($attacker, $attack);

        Sanctum::actingAs($attacker);
        $this->postJson('/api/clans/leave')->assertNoContent();

        $this->assertModelMissing($pending);
        $this->assertDatabaseHas('clan_actions', ['run_id' => $begun->id, 'result' => 'cancelled']);
        $this->postJson("/api/clan-attacks/{$attack->id}/improve")->assertStatus(422)
            ->assertJsonPath('message', 'Seul l\'attaquant peut améliorer son attaque.');
        $this->postJson("/api/clan-attacks/{$attack->id}/cancel")->assertStatus(422)
            ->assertJsonPath('message', 'Seuls l\'attaquant, le chef de clan et ses bras droits peuvent annuler cette attaque.');
        $this->assertSame(ClanAttackStatus::ACTIVE, $attack->fresh()->status);

        // excluded: the same
        $attack->update(['status' => ClanAttackStatus::CANCELLED]);
        $clan->members()->create(['user_id' => $attacker->id]);
        $warService->startAttack($attacker, $defender, $other);
        Sanctum::actingAs($leader);
        $this->postJson("/api/clans/{$clan->id}/members/{$attacker->etwin_id}/kick")->assertNoContent();
        $this->assertSame(0, ClanAction::query()->where('user_id', $attacker->id)->whereNull('completed_at')->count());
    }

    // asked, then checked again when the run begins: the maximum of attacks reached meanwhile, or out of the clan
    public function test_a_new_attack_is_checked_again_when_it_begins(): void
    {
        $period = $this->period();
        $attacker = User::factory()->create();
        $clan = Clan::factory()->withLeader($attacker)->create();
        $defender = Clan::factory()->withLeader()->create();
        [$game, $other] = Game::factory()->count(2)->create();
        $runService = app(ClanRunService::class);

        $action = app(ClanWarService::class)->startAttack($attacker, $defender, $game);
        $this->assertTrue($action->is($runService->pendingAction($attacker->id, $game->id)));

        // (another attack launched meanwhile)
        ClanAttack::query()->create([
            'period_id' => $period->id, 'game_id' => $other->id, 'attacker_clan_id' => $clan->id, 'attacker_user_id' => $attacker->id,
            'defender_clan_id' => $defender->id, 'score' => 100, 'status' => ClanAttackStatus::ACTIVE, 'expires_at' => now()->addHours(12),
        ]);
        $this->assertNull($runService->pendingAction($attacker->id, $game->id));
        $this->assertModelMissing($action);

        // out of the clan
        ClanAttack::query()->update(['status' => ClanAttackStatus::CANCELLED]);
        $action = ClanAction::query()->create([
            'clan_id' => $defender->id, 'user_id' => $attacker->id, 'game_id' => $game->id, 'type' => ClanActionType::ATTACK, 'defender_clan_id' => $clan->id,
        ]);
        $this->assertNull($runService->pendingAction($attacker->id, $game->id));
        $this->assertModelMissing($action);
    }

    // in a search: whatever the case, the wildcards searched as text, and the rank in the whole ranking
    public function test_searching_the_ranking(): void
    {
        $period = $this->period();
        $pirates = Clan::factory()->withLeader()->create(['name' => 'Les Pirates']);
        $best = Clan::factory()->withLeader()->create(['name' => 'Dino RPG']);
        $idle = Clan::factory()->withLeader()->create(['name' => 'Pirates du soir']);
        $second = Clan::factory()->withLeader()->create(['name' => 'Kado Club']);
        ClanPeriodScore::query()->create(['clan_id' => $best->id, 'period_id' => $period->id, 'war_score' => 42, 'mission_score' => 1]);
        ClanPeriodScore::query()->create(['clan_id' => $second->id, 'period_id' => $period->id, 'war_score' => 5]);
        ClanPeriodScore::query()->create(['clan_id' => $pirates->id, 'period_id' => $period->id, 'mission_score' => 7]);
        $service = app(ClanService::class);

        Sanctum::actingAs(User::factory()->create());
        $this->getJson('/api/clans?q=PIRATES')->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.id', $pirates->id)
            ->assertJsonPath('data.0.rank', 3)
            ->assertJsonPath('data.1.id', $idle->id)
            ->assertJsonPath('data.1.rank', 4);
        $this->getJson('/api/clans?q=pirates&ranking=missions')->assertOk()
            ->assertJsonPath('data.0.rank', 1)
            ->assertJsonPath('data.1.rank', 3);
        foreach ([$pirates, $best, $idle, $second] as $clan) {
            foreach (['war', 'missions'] as $ranking) {
                $this->assertSame($service->rankOf($clan, $period, $ranking), $service->ranksOf([$clan->id], $period, $ranking)->get($clan->id));
            }
        }
        $this->getJson('/api/clans?q='.urlencode('P%s'))->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/clans?q=_')->assertOk()->assertJsonCount(4, 'data')->assertJsonPath('data.0.rank', 1);
    }

    // another clan looking at the missions creates nothing (its score of the period, its options)
    public function test_looking_at_the_missions_of_another_clan_creates_nothing(): void
    {
        $period = $this->period();
        $idle = Clan::factory()->withLeader()->create();
        Sanctum::actingAs(User::factory()->create());

        $this->getJson("/api/clans/{$idle->id}/missions")->assertOk()
            ->assertJsonPath('data.mission', null)
            ->assertJsonPath('data.mission_score', 0)
            ->assertJsonPath('data.missions_completed', 0);
        $this->assertDatabaseMissing('clan_period_scores', ['clan_id' => $idle->id]);
        $this->assertDatabaseMissing('clan_bonuses', ['clan_id' => $idle->id]);

        ClanPeriodScore::query()->create(['clan_id' => $idle->id, 'period_id' => $period->id, 'mission_score' => 12, 'missions_completed' => 2]);
        $this->getJson("/api/clans/{$idle->id}/missions")->assertOk()
            ->assertJsonPath('data.mission_score', 12)
            ->assertJsonPath('data.missions_completed', 2);
    }

    // the name unique whatever the case in the database too (two clans created at the same time both pass the rule)
    public function test_two_clans_can_not_have_the_same_name_whatever_the_case(): void
    {
        $this->period();
        Clan::factory()->withLeader()->create(['name' => 'Les Pirates']);
        $user = User::factory()->create(['kado_points' => 5000]);

        try {
            app(ClanService::class)->create($user, 'les PIRATES', null);
            $this->fail('Two clans have the same name.');
        } catch (ValidationException $e) {
            $this->assertSame(['name' => ['Ce nom de clan est déjà pris.']], $e->errors());
        }
        $this->assertSame(5000, $user->fresh()->kado_points);
        $this->assertSame(0, $user->clanMember()->count());
    }

    public function test_the_index_of_the_names_is_refused_while_two_clans_have_the_same_name(): void
    {
        $migration = require database_path('migrations/2026_10_19_000004_add_lower_name_index_to_clans.php');
        $migration->down();
        $foo = Clan::factory()->create(['name' => 'Foo']);
        Clan::factory()->create(['name' => 'foo']);

        try {
            $migration->up();
            $this->fail('The index was built.');
        } catch (\RuntimeException $e) {
            $this->assertStringContainsString("#{$foo->id} Foo", $e->getMessage());
        }

        $foo->update(['name' => 'Foo 2']);
        $migration->up();
        $this->expectException(\Illuminate\Database\UniqueConstraintViolationException::class);
        DB::table('clans')->insert(['name' => 'FOO 2', 'created_at' => now(), 'updated_at' => now()]);
    }
}
