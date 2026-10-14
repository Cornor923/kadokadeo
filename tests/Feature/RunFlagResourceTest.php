<?php

namespace Tests\Feature;

use App\Enums\RunFlagRule;
use App\Enums\RunFlagStatus;
use App\Filament\Resources\RunFlags\Pages\ListRunFlags;
use App\Models\Run;
use App\Models\RunFlag;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class RunFlagResourceTest extends TestCase
{
    use RefreshDatabase;

    private function flag(array $run = []): RunFlag
    {
        $run = Run::factory()->create($run);

        return RunFlag::create([
            'run_id' => $run->id,
            'user_id' => $run->user_id,
            'game_id' => $run->game_id,
            'rule' => RunFlagRule::CLIENT_DETECTION,
            'severity' => 2,
            'details' => ['bits' => 0x10],
        ]);
    }

    public function test_the_admin_sees_the_open_flags(): void
    {
        $admin = User::factory()->create(['is_admin' => true]);
        $this->actingAs($admin);
        $open = $this->flag();
        $dismissed = $this->flag();
        $dismissed->update(['status' => RunFlagStatus::DISMISSED]);
        $cheat = $this->flag(['is_cheat' => true]);

        $this->get('/admin/run-flags')->assertOk()->assertSee('Runs suspectes');
        Livewire::test(ListRunFlags::class)
            ->assertCanSeeTableRecords([$open])
            ->assertCanNotSeeTableRecords([$dismissed, $cheat]);
    }

    public function test_the_admin_sees_which_detections_mark_a_run_as_cheated(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));
        config(['kado.anticheat.soft_bits' => 0x3F0]);

        Livewire::test(ListRunFlags::class)
            ->assertActionExists('detectionRules')
            ->mountAction('detectionRules')
            ->assertMountedActionModalSee(['Marquées triche automatiquement', 'Code du jeu remplacé', 'KADO_ANTICHEAT_SOFT_BITS = 0x3F0', 'Ignorées', 'KADO_ANTICHEAT_IGNORED_BITS = 0xC0']);
        $this->assertStringContainsString(
            'Envoyées ici pour examen (KADO_ANTICHEAT_SOFT_BITS = 0x3F0) : Affichage ajouté par un script, PIXI modifié, Faux événements, Vérification impossible. Ignorées (KADO_ANTICHEAT_IGNORED_BITS = 0xC0) : Fonctions du navigateur modifiées, Actions générées par un script.',
            \App\Filament\AntiCheatNotices::detectionRules(),
        );
    }

    public function test_the_admin_panel_warns_when_the_checks_of_the_replays_are_off(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));

        config(['kado.require_rng_stir' => false, 'kado.require_input_phases' => false]);
        $this->get('/admin/run-flags')->assertOk()->assertSee('Anti-triche incomplet')
            ->assertSee('KADO_REQUIRE_RNG_STIR')->assertSee('KADO_REQUIRE_INPUT_PHASES');

        config(['kado.require_rng_stir' => true, 'kado.require_input_phases' => true]);
        $this->get('/admin/run-flags')->assertOk()->assertDontSee('Anti-triche incomplet');
    }

    public function test_the_admin_dismisses_a_flag_or_confirms_the_cheat(): void
    {
        $admin = User::factory()->create(['is_admin' => true]);
        $this->actingAs($admin);
        $dismissed = $this->flag();
        $confirmed = $this->flag(['score' => 500]);

        Livewire::test(ListRunFlags::class)
            ->callTableAction('dismiss', $dismissed)
            ->callTableAction('confirmCheat', $confirmed)
            ->assertHasNoTableActionErrors();

        $this->assertSame(RunFlagStatus::DISMISSED, $dismissed->fresh()->status);
        $this->assertSame($admin->id, $dismissed->fresh()->reviewed_by);
        $this->assertSame(RunFlagStatus::CONFIRMED, $confirmed->fresh()->status);
        $this->assertTrue($confirmed->run->fresh()->is_cheat);
    }
}
