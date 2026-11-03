<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

// the SPA and the games are authenticated by the session of the site (Sanctum statefulApi, guard web), the tokens are
// still accepted (the pages opened before the session cookies)
class SessionAuthTest extends TestCase
{
    use RefreshDatabase;

    // a request of the site: its origin is one of the stateful domains of Sanctum
    private function fromTheSite(): static
    {
        return $this->withHeader('Referer', config('app.url').'/games');
    }

    public function test_the_session_of_the_site_authenticates_the_api(): void
    {
        $user = User::factory()->create();

        $this->fromTheSite()->actingAs($user, 'web')
            ->getJson('/api/user')
            ->assertOk()
            ->assertJsonPath('data.id', $user->id);
    }

    public function test_no_session_no_player(): void
    {
        $this->fromTheSite()->getJson('/api/user')->assertUnauthorized();
    }

    public function test_the_logout_ends_the_session(): void
    {
        $user = User::factory()->create();

        $this->fromTheSite()->actingAs($user, 'web')
            ->postJson('/api/logout')
            ->assertNoContent();

        $this->assertGuest('web');
    }

    public function test_the_logout_of_a_page_opened_before_the_session_revokes_its_token(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('kadokadeo')->plainTextToken;

        $this->withToken($token)->postJson('/api/logout')->assertNoContent();

        $this->assertSame(0, $user->tokens()->count());
    }

    public function test_an_old_tab_sending_its_token_while_the_session_is_open_loses_both(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('kadokadeo')->plainTextToken;

        $this->fromTheSite()->actingAs($user, 'web')->withToken($token)
            ->postJson('/api/logout')
            ->assertNoContent();

        $this->assertGuest('web');
        $this->assertSame(0, $user->tokens()->count());
    }

    public function test_a_banned_player_loses_their_session(): void
    {
        $user = User::factory()->create();
        $user->update(['banned_at' => now()]);

        $this->fromTheSite()->actingAs($user, 'web')
            ->getJson('/api/user')
            ->assertForbidden()
            ->assertJsonPath('banned', true);

        $this->assertGuest('web');
    }
}
