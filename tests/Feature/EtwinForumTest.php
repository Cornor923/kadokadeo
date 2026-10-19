<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request as ClientRequest;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class EtwinForumTest extends TestCase
{
    use RefreshDatabase;

    private const ETWIN = 'http://etwin.test';

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.etwin.eternaltwinUrl' => self::ETWIN.'/', 'services.etwin.scope' => 'forum:write']);
    }

    private function player(bool $canWrite): User
    {
        $user = User::factory()->create([
            'etwin_access_token' => 'token-of-the-player',
            'etwin_scopes' => ['base' => true, 'forum_read' => true, 'forum_write' => $canWrite, 'forum_moderate' => false],
        ]);
        Sanctum::actingAs($user);

        return $user;
    }

    public function test_the_status_says_what_the_player_can_do(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $this->getJson('/api/etwin-forum/status')
            ->assertOk()
            ->assertJsonPath('data.category', 'kadokadeo')
            ->assertJsonPath('data.can_write', false)
            ->assertJsonPath('data.needs_login', true);

        $this->player(true);
        $this->getJson('/api/etwin-forum/status')
            ->assertJsonPath('data.can_write', true)
            ->assertJsonPath('data.needs_login', false);
    }

    // the reads go to Eternaltwin as they are, with the token of the player and the page asked
    public function test_the_reads_are_sent_as_the_player(): void
    {
        Http::fake([self::ETWIN.'/api/v1/forum/sections/kadokadeo_main*' => Http::response(['type' => 'ForumSection', 'key' => 'kadokadeo_main'])]);
        $this->player(false);

        $this->getJson('/api/etwin-forum/sections/kadokadeo_main?offset=20&limit=20&other=1')
            ->assertOk()
            ->assertJsonPath('key', 'kadokadeo_main');
        Http::assertSent(fn (ClientRequest $request) => $request->url() === self::ETWIN.'/api/v1/forum/sections/kadokadeo_main?offset=20&limit=20'
            && $request->hasHeader('Authorization', 'Bearer token-of-the-player'));
    }

    // only the requests of the forum the site uses go through
    public function test_the_other_paths_are_not_found(): void
    {
        Http::fake();
        $this->player(true);

        $this->getJson('/api/etwin-forum/reports')->assertNotFound();
        $this->getJson('/api/etwin-forum/sections/../users')->assertNotFound();
        $this->postJson('/api/etwin-forum/sanctions')->assertNotFound();
        $this->patchJson('/api/etwin-forum/threads/abc')->assertNotFound();
        Http::assertNothingSent();
    }

    // writing needs the scope forum:write: without it, the player is asked to log in again
    public function test_writing_needs_the_scope(): void
    {
        Http::fake();
        $this->player(false);

        $this->postJson('/api/etwin-forum/threads/abc', ['body' => 'Salut'])
            ->assertForbidden()
            ->assertJsonPath('needs_login', true);
        Http::assertNothingSent();
    }

    public function test_a_reply_is_sent_with_its_body_only(): void
    {
        Http::fake([self::ETWIN.'/api/v1/forum/threads/*' => Http::response(['type' => 'ForumPost', 'id' => 'p1'], 200)]);
        $this->player(true);

        $this->postJson('/api/etwin-forum/threads/7a6d6b95-510b-44c2-b4e5-9c367e94ab71', ['body' => '**Salut** :kk-piou:', 'admin' => true])
            ->assertOk()
            ->assertJsonPath('id', 'p1');
        Http::assertSent(fn (ClientRequest $request) => $request->method() === 'POST'
            && $request->data() === ['body' => '**Salut** :kk-piou:']);
    }

    // a refusal keeps the error of Eternaltwin and gets a message in French
    public function test_a_refusal_is_explained(): void
    {
        Http::fake([self::ETWIN.'/api/v1/forum/sections/*' => Http::response(['error' => 'cannot create a thread in a category'], 400)]);
        $this->player(true);

        $this->postJson('/api/etwin-forum/sections/kadokadeo', ['title' => 'Test', 'body' => 'Test'])
            ->assertStatus(400)
            ->assertJsonPath('error', 'cannot create a thread in a category')
            ->assertJsonPath('message', 'Le message n\'a pas pu être lu par le forum (Marktwin invalide) ou cette section ne reçoit pas de sujets.');
    }

    // a token Eternaltwin can't read any more is forgotten: the player logs in again
    public function test_a_broken_token_is_forgotten(): void
    {
        Http::fake([self::ETWIN.'/api/v1/forum/*' => Http::response(['error' => 'invalid credentials'], 401)]);
        $user = $this->player(true);

        $this->postJson('/api/etwin-forum/read_floor')
            ->assertForbidden()
            ->assertJsonPath('needs_login', true);
        $this->assertNull($user->refresh()->etwin_access_token);
    }

    public function test_eternaltwin_down_is_reported(): void
    {
        Http::fake(fn () => throw new \Illuminate\Http\Client\ConnectionException('down'));
        $this->player(false);

        $this->getJson('/api/etwin-forum/sections')
            ->assertStatus(502)
            ->assertJsonPath('message', 'Le forum d\'Eternaltwin ne répond pas, réessayez plus tard.');
    }
}
