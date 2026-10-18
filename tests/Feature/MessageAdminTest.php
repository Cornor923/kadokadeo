<?php

namespace Tests\Feature;

use App\Filament\Resources\Messages\Pages\ListMessages;
use App\Models\Message;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class MessageAdminTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $this->admin = User::factory()->create(['is_admin' => true]);
        $this->actingAs($this->admin);
    }

    // the admin sees the messages of all the players, and the ones of the site
    public function test_the_admin_sees_all_the_messages(): void
    {
        [$alice, $bob] = User::factory()->count(2)->create();
        $private = Message::query()->create(['sender_id' => $alice->id, 'recipient_id' => $bob->id, 'subject' => 'Salut', 'body' => '**Coucou**']);
        $system = Message::query()->create(['sender_id' => null, 'recipient_id' => $bob->id, 'subject' => 'Bienvenue', 'body' => 'Bienvenue !']);

        $this->get('/admin/messages')->assertOk()->assertSee('Messages privés');
        Livewire::test(ListMessages::class)
            ->assertCanSeeTableRecords([$private, $system])
            ->filterTable('type', 'system')
            ->assertCanSeeTableRecords([$system])
            ->assertCanNotSeeTableRecords([$private]);

        // the body is rendered by <kado-marktwin> (resources/js/admin/marktwin.js)
        Livewire::test(ListMessages::class)
            ->mountTableAction('read', $private)
            ->assertMountedActionModalSee(['De', $alice->display_name, $bob->display_name, 'Pas encore lu', '<kado-marktwin text="**Coucou**">'], escape: false);
    }

    public function test_a_player_can_not_see_the_messages(): void
    {
        $this->actingAs(User::factory()->create());

        $this->get('/admin/messages')->assertForbidden();
    }

    // a message signed "KadoKado" to a player
    public function test_the_admin_sends_a_message_to_a_player(): void
    {
        $player = User::factory()->create();

        Livewire::test(ListMessages::class)
            ->callAction('sendSystemMessage', data: [
                'target' => 'one',
                'recipient_id' => $player->id,
                'subject' => 'Nouvelle période',
                'body' => "**Bravo** pour ta période !\n:kk-biggrin:",
            ])
            ->assertHasNoActionErrors()
            ->assertNotified("Message envoyé à {$player->display_name}.");

        $this->assertDatabaseHas('messages', [
            'sender_id' => null,
            'recipient_id' => $player->id,
            'subject' => 'Nouvelle période',
            'body' => "**Bravo** pour ta période !\n:kk-biggrin:",
        ]);
    }

    // to every player not banned, once confirmed
    public function test_the_admin_sends_a_message_to_all_the_players(): void
    {
        $players = User::factory()->count(3)->create();
        $banned = User::factory()->create(['banned_at' => now()]);
        $data = ['target' => 'all', 'subject' => 'Maintenance', 'body' => 'Le site sera _fermé_ demain.'];

        Livewire::test(ListMessages::class)
            ->callAction('sendSystemMessage', data: $data)
            ->assertHasActionErrors(['confirm_all' => 'accepted']);
        $this->assertDatabaseCount('messages', 0);

        Livewire::test(ListMessages::class)
            ->callAction('sendSystemMessage', data: [...$data, 'confirm_all' => true])
            ->assertHasNoActionErrors()
            ->assertNotified('Message envoyé à 4 joueur(s).');

        // the 3 players and the admin, not the banned player
        $this->assertSame(4, Message::query()->whereNull('sender_id')->where('subject', 'Maintenance')->count());
        foreach ([...$players, $this->admin] as $player) {
            $this->assertDatabaseHas('messages', ['recipient_id' => $player->id, 'subject' => 'Maintenance']);
        }
        $this->assertDatabaseMissing('messages', ['recipient_id' => $banned->id]);
    }

    public function test_a_player_is_required_to_send_to_one(): void
    {
        Livewire::test(ListMessages::class)
            ->callAction('sendSystemMessage', data: ['target' => 'one', 'subject' => 'Test', 'body' => 'Test'])
            ->assertHasActionErrors(['recipient_id' => 'required']);
    }
}
