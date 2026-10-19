<?php

namespace Tests\Feature;

use App\Filament\Resources\Users\Pages\CreateUser;
use App\Filament\Resources\Users\Pages\EditUser;
use App\Filament\Resources\Users\Pages\ListUsers;
use App\Models\Period;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class UserAdminTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $this->admin = User::factory()->create(['is_admin' => true]);
        $this->actingAs($this->admin);
    }

    // the counters are read-only: the form saved for another field does not write back the values loaded with the
    // page (the points won meanwhile are kept)
    public function test_saving_the_form_keeps_the_counters_changed_meanwhile(): void
    {
        $player = User::factory()->create(['kado_points' => 100, 'kado_games' => 5, 'clan_games' => 2]);
        $page = Livewire::test(EditUser::class, ['record' => $player->getRouteKey()])
            ->assertFormFieldIsDisabled('kado_points')
            ->assertFormFieldIsDisabled('kado_games')
            ->assertFormFieldIsDisabled('clan_games')
            ->assertFormFieldIsDisabled('clan_attack_games');

        User::query()->whereKey($player->id)->update(['kado_points' => 150, 'kado_games' => 4, 'clan_games' => 3]);
        $page->fillForm(['display_name' => 'Renamed', 'kado_points' => 9999])
            ->call('save')
            ->assertHasNoFormErrors();

        $player->refresh();
        $this->assertSame('Renamed', $player->display_name);
        $this->assertSame(150, $player->kado_points);
        $this->assertSame(4, $player->kado_games);
        $this->assertSame(3, $player->clan_games);
    }

    // the counters are given when the player is created
    public function test_the_counters_are_saved_on_creation(): void
    {
        Livewire::test(CreateUser::class)
            ->fillForm(['etwin_id' => 'etwin-new', 'display_name' => 'Nouveau', 'kado_points' => 10, 'kado_games' => 3, 'clan_games' => 1, 'clan_attack_games' => 2])
            ->call('create')
            ->assertHasNoFormErrors();

        $player = User::query()->where('etwin_id', 'etwin-new')->sole();
        $this->assertSame([10, 3, 1, 2], [$player->kado_points, $player->kado_games, $player->clan_games, $player->clan_attack_games]);
    }

    // a signed delta added to the balance of the moment, with its user_points row
    public function test_the_admin_adjusts_the_kado_points(): void
    {
        $period = Period::factory()->create(['start_at' => now()->subDay(), 'end_at' => now()->addDays(5)]);
        $player = User::factory()->create(['kado_points' => 100]);
        $page = Livewire::test(EditUser::class, ['record' => $player->getRouteKey()]);
        User::query()->whereKey($player->id)->increment('kado_points', 20);

        $page->callAction('adjustKadoPoints', ['delta' => -30])
            ->assertHasNoActionErrors()
            ->assertNotified('Points Kado ajustés.')
            ->assertFormSet(['kado_points' => 90]);

        $this->assertSame(90, $player->fresh()->kado_points);
        $this->assertDatabaseHas('user_points', [
            'user_id' => $player->id,
            'period_id' => $period->id,
            'delta' => -30,
            'reason' => 'admin adjustment',
            'source_type' => User::class,
            'source_id' => $this->admin->id,
        ]);

        $page->callAction('adjustKadoPoints', ['delta' => 0])->assertHasActionErrors(['delta']);
        $this->assertSame(90, $player->fresh()->kado_points);
    }

    public function test_the_admin_adjusts_the_games_without_going_below_zero(): void
    {
        $player = User::factory()->create(['kado_games' => 5, 'clan_games' => 1, 'clan_attack_games' => 2]);

        Livewire::test(ListUsers::class)
            ->callTableAction('adjustGames', $player, ['kado_games' => 3, 'clan_games' => -1, 'clan_attack_games' => 0])
            ->assertHasNoTableActionErrors()
            ->assertNotified('Parties ajustées.');

        $player->refresh();
        $this->assertSame([8, 0, 2], [$player->kado_games, $player->clan_games, $player->clan_attack_games]);

        // a counter below 0: nothing changed
        Livewire::test(ListUsers::class)
            ->callTableAction('adjustGames', $player, ['kado_games' => 1, 'clan_games' => -1, 'clan_attack_games' => 0])
            ->assertNotified('Parties non ajustées.');

        $player->refresh();
        $this->assertSame([8, 0, 2], [$player->kado_games, $player->clan_games, $player->clan_attack_games]);
    }
}
