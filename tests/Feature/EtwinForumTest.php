<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

// the forum of Eternaltwin is embedded: the site only says where it is and gives the token of the player to its script
class EtwinForumTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'services.etwin.eternaltwinUrl' => 'http://kadokadeo_eternaltwin:50320/',
            'services.etwin.publicUrl' => 'https://eternaltwin.test/',
            'services.etwin.scope' => 'base forum:read forum:write',
        ]);
    }

    private function player(array $scopes): User
    {
        $user = User::factory()->create([
            'etwin_access_token' => 'token-of-the-player',
            'etwin_scopes' => ['base' => true, 'forum_read' => false, 'forum_write' => false, 'forum_moderate' => false, ...$scopes],
        ]);
        Sanctum::actingAs($user);

        return $user;
    }

    // the browser loads the forum from the public address of Eternaltwin, not the one the server reaches it at
    public function test_the_status_says_where_the_forum_is_and_what_the_player_can_do(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $this->getJson('/api/etwin-forum/status')
            ->assertOk()
            ->assertJsonPath('data.url', 'https://eternaltwin.test')
            ->assertJsonPath('data.group', 'kadokadeo')
            ->assertJsonPath('data.can_write', false)
            ->assertJsonPath('data.needs_login', true);

        $this->player(['forum_read' => true, 'forum_write' => true]);
        $this->getJson('/api/etwin-forum/status')
            ->assertJsonPath('data.can_write', true)
            ->assertJsonPath('data.needs_login', false);
    }

    public function test_the_token_is_given_to_a_player_who_allowed_the_forum(): void
    {
        $this->player(['forum_read' => true]);

        $response = $this->getJson('/api/etwin-forum/token')
            ->assertOk()
            ->assertExactJson(['access_token' => 'token-of-the-player']);
        $this->assertStringContainsString('no-store', (string) $response->headers->get('Cache-Control'));
    }

    // without the scope forum:read, the forum would read as a guest anyway: the player is asked to log in again
    public function test_the_token_needs_the_scope(): void
    {
        $this->player([]);

        $this->getJson('/api/etwin-forum/token')
            ->assertForbidden()
            ->assertJsonPath('needs_login', true);
    }

    public function test_the_token_needs_a_token(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/etwin-forum/token')
            ->assertForbidden()
            ->assertJsonPath('needs_login', true);
    }

    public function test_the_token_is_not_given_to_a_guest(): void
    {
        $this->getJson('/api/etwin-forum/token')->assertUnauthorized();
    }

    // the old proxy of the forum is gone: a write meets only the fallback of the pages (GET), and nothing is sent to
    // Eternaltwin
    public function test_the_forum_is_no_longer_relayed(): void
    {
        Http::fake();
        $this->player(['forum_read' => true, 'forum_write' => true]);

        $this->postJson('/api/etwin-forum/threads/abc', ['body' => 'Bonjour'])->assertMethodNotAllowed();
        $this->patchJson('/api/etwin-forum/posts/abc', ['content' => 'Bonjour'])->assertMethodNotAllowed();
        Http::assertNothingSent();
    }
}
