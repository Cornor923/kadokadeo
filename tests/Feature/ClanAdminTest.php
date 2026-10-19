<?php

namespace Tests\Feature;

use App\Enums\ClanBonusType;
use App\Enums\ClanRole;
use App\Filament\Resources\Clans\Pages\EditClan;
use App\Filament\Resources\Clans\RelationManagers\BonusesRelationManager;
use App\Filament\Resources\Clans\RelationManagers\MembersRelationManager;
use App\Filament\Resources\Clans\RelationManagers\MissionsRelationManager;
use App\Models\Clan;
use App\Models\ClanBonus;
use App\Models\ClanMemberStat;
use App\Models\ClanMission;
use App\Models\ClanPeriodScore;
use App\Models\Game;
use App\Models\Period;
use App\Models\User;
use App\Services\ClanMissionService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

// the page of a clan in the admin: its missions (and "Régénérer la mission en cours"), its options, its chest
class ClanAdminTest extends TestCase
{
    use RefreshDatabase;

    private Period $period;

    private Clan $clan;

    protected function setUp(): void
    {
        parent::setUp();
        $this->period = Period::factory()->create(['start_at' => now()->subDay()->startOfDay(), 'end_at' => now()->addDays(12)->endOfDay()]);
        $this->clan = Clan::factory()->withLeader()->create(['clan_games' => 4]);
        Game::factory()->count(8)->create(['stars' => [1000, 2000, 3000]]);
        $this->actingAs(User::factory()->create(['is_admin' => true]));
    }

    private function relation(string $class)
    {
        return Livewire::test($class, ['ownerRecord' => $this->clan, 'pageClass' => EditClan::class]);
    }

    public function test_the_admin_sees_the_missions_and_their_steps(): void
    {
        $mission = app(ClanMissionService::class)->currentMission($this->clan);
        $step = $mission->steps()->with('game')->first();

        $this->relation(MissionsRelationManager::class)
            ->assertCanSeeTableRecords([$mission])
            ->assertSee('En cours')
            ->assertSee('0 / '.$mission->steps()->count())
            ->mountTableAction('steps', $mission)
            ->assertMountedActionModalSee([$step->game->name, number_format($step->target_score, 0, ',', ' '), 'À faire']);
    }

    public function test_the_admin_regenerates_the_mission_in_progress_without_losing_points(): void
    {
        ClanPeriodScore::query()->create(['clan_id' => $this->clan->id, 'period_id' => $this->period->id, 'mission_score' => 12, 'missions_completed' => 2]);
        $old = app(ClanMissionService::class)->currentMission($this->clan);
        $this->assertSame(3, $old->number);

        $this->relation(MissionsRelationManager::class)->callTableAction('regenerate')->assertHasNoTableActionErrors();

        $this->assertSame(ClanMission::SKIPPED, $old->fresh()->status);
        $this->assertSame(0, $old->fresh()->points);
        $new = ClanMission::query()->where('status', ClanMission::ACTIVE)->sole();
        $this->assertSame(3, $new->number);
        $this->assertNotSame($old->id, $new->id);
        $this->assertSame(12, ClanPeriodScore::query()->where('clan_id', $this->clan->id)->value('mission_score'));
    }

    public function test_a_clan_without_mission_gets_one(): void
    {
        $this->relation(MissionsRelationManager::class)->callTableAction('regenerate');

        $this->assertSame(1, ClanMission::query()->where('clan_id', $this->clan->id)->where('status', ClanMission::ACTIVE)->count());
        $this->assertSame(0, ClanMission::query()->where('clan_id', $this->clan->id)->where('status', ClanMission::SKIPPED)->count());
    }

    public function test_the_admin_gives_and_takes_back_an_option(): void
    {
        $this->relation(BonusesRelationManager::class)
            ->callTableAction('create', data: ['type' => ClanBonusType::SKIP_STEP->value, 'period_id' => $this->period->id])
            ->assertHasNoTableActionErrors();
        $bonus = ClanBonus::query()->where('clan_id', $this->clan->id)->where('type', ClanBonusType::SKIP_STEP)->sole();
        $this->assertNull($bonus->used_at);

        $this->relation(BonusesRelationManager::class)
            ->assertCanSeeTableRecords([$bonus])
            ->callTableAction('delete', $bonus);
        $this->assertModelMissing($bonus);
    }

    public function test_the_admin_sees_the_members_and_their_stats_of_a_period(): void
    {
        $leader = $this->clan->leader;
        $rightHand = User::factory()->create(['display_name' => 'Bras Droit']);
        $member = $this->clan->members()->create(['user_id' => $rightHand->id, 'role' => ClanRole::RIGHT_HAND]);
        ClanMemberStat::query()->create(['clan_id' => $this->clan->id, 'user_id' => $rightHand->id, 'period_id' => $this->period->id,
            'attacks' => 3, 'attacks_won' => 2, 'defenses' => 1, 'defenses_won' => 1, 'mission_steps' => 4, 'performance' => 15]);
        $old = Period::factory()->create(['start_at' => now()->subDays(30), 'end_at' => now()->subDays(16)]);
        ClanMemberStat::query()->create(['clan_id' => $this->clan->id, 'user_id' => $rightHand->id, 'period_id' => $old->id, 'mission_steps' => 40]);

        $this->relation(MembersRelationManager::class)
            ->assertCanSeeTableRecords([$member])
            ->assertTableColumnStateSet('stat_points', 19, $member)
            ->assertTableColumnFormattedStateSet('stat_attacks_won', '2 / 3', $member)
            ->assertTableColumnStateSet('role', ClanRole::RIGHT_HAND, $member)
            ->assertTableColumnStateSet('role', ClanRole::LEADER, $leader->clanMember)
            ->sortTable('stat_points', 'desc')
            ->assertCanSeeTableRecords([$member, $leader->clanMember], inOrder: true)
            ->filterTable('period_id', $old->id)
            ->assertTableColumnStateSet('stat_points', 40, $member)
            ->assertTableColumnStateSet('stat_attacks_won', 0, $member);
    }

    public function test_the_admin_changes_the_chest_of_the_clan(): void
    {
        Livewire::test(EditClan::class, ['record' => $this->clan->getRouteKey()])
            ->assertSet('data.clan_games', 4)
            ->set('data.clan_games', 25)
            ->call('save')
            ->assertHasNoErrors();
        $this->assertSame(25, $this->clan->fresh()->clan_games);

        Livewire::test(EditClan::class, ['record' => $this->clan->getRouteKey()])
            ->set('data.clan_games', -1)
            ->call('save')
            ->assertHasErrors(['data.clan_games']);
    }
}
