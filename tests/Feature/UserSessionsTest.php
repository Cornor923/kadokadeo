<?php

namespace Tests\Feature;

use App\Filament\Resources\Users\Pages\EditUser;
use App\Filament\Resources\Users\RelationManagers\SessionsRelationManager;
use App\Models\Session;
use App\Models\User;
use Filament\Actions\Testing\TestAction;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Livewire\Livewire;
use Tests\TestCase;

// the tab « Sessions » of a player in the admin: their browsers, and their logout from all of them
class UserSessionsTest extends TestCase
{
    use RefreshDatabase;

    private function openSession(User $user, string $userAgent, int $minutesAgo): string
    {
        $id = Str::random(40);
        DB::table('sessions')->insert([
            'id' => $id,
            'user_id' => $user->id,
            'ip_address' => '203.0.113.7',
            'user_agent' => $userAgent,
            'payload' => base64_encode(serialize(['_token' => 'secret-csrf-token'])),
            'last_activity' => now()->subMinutes($minutesAgo)->getTimestamp(),
        ]);

        return $id;
    }

    public function test_the_admin_sees_the_browsers_of_the_player(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));
        $player = User::factory()->create();
        $other = User::factory()->create();
        $this->openSession($player, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:131.0) Gecko/20100101 Firefox/131.0', 5);
        $this->openSession($player, 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1', 60 * 24 * 3);
        $this->openSession($other, 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36', 1);

        Livewire::test(SessionsRelationManager::class, ['ownerRecord' => $player, 'pageClass' => EditUser::class])
            ->assertOk()
            ->assertCanSeeTableRecords(Session::query()->where('user_id', $player->id)->get())
            ->assertCanNotSeeTableRecords(Session::query()->where('user_id', $other->id)->get())
            ->assertSee('Firefox · Windows')
            ->assertSee('Safari · iOS')
            ->assertSee('203.0.113.7')
            ->assertSee('Active')
            ->assertSee('Expirée')
            ->assertDontSee('secret-csrf-token');
    }

    public function test_the_admin_logs_the_player_out_everywhere(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));
        $player = User::factory()->create(['remember_token' => 'the-old-remember-token']);
        $other = User::factory()->create();
        $this->openSession($player, 'Firefox', 5);
        $this->openSession($player, 'Safari', 10);
        $this->openSession($other, 'Chrome', 1);
        $player->createToken('kadokadeo');

        Livewire::test(SessionsRelationManager::class, ['ownerRecord' => $player, 'pageClass' => EditUser::class])
            ->callAction(TestAction::make('logOutEverywhere')->table())
            ->assertNotified();

        $this->assertSame(0, Session::query()->where('user_id', $player->id)->count());
        $this->assertSame(1, Session::query()->where('user_id', $other->id)->count());
        $this->assertNotSame('the-old-remember-token', $player->fresh()->getRememberToken());
        $this->assertSame(0, $player->tokens()->count());
    }
}
