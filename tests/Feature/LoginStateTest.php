<?php

namespace Tests\Feature;

use App\Http\Controllers\LoginController;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Symfony\Component\HttpFoundation\Cookie;
use Tests\TestCase;

class LoginStateTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_login_gives_the_browser_a_random_state_sent_to_eternaltwin(): void
    {
        $response = $this->get('/login')->assertRedirect();

        $cookie = collect($response->headers->getCookies())->first(fn (Cookie $c) => $c->getName() === LoginController::OAUTH_STATE_COOKIE);
        $this->assertNotNull($cookie);
        $this->assertSame(40, strlen($cookie->getValue()));
        $this->assertSame('/api/oauth', $cookie->getPath());
        $this->assertTrue($cookie->isHttpOnly());
        $this->assertStringContainsString('state='.$cookie->getValue(), $response->headers->get('Location'));
    }

    public function test_a_code_sent_without_the_state_of_the_browser_is_refused(): void
    {
        // a link to the callback with the code of someone else: no state in this browser
        $this->getJson('/api/oauth/callback?code=abc&state=xyz')->assertStatus(422);
        // the state of another login
        $this->withUnencryptedCookie(LoginController::OAUTH_STATE_COOKIE, 'other')
            ->getJson('/api/oauth/callback?code=abc&state=xyz')
            ->assertStatus(422);
        $this->withUnencryptedCookie(LoginController::OAUTH_STATE_COOKIE, 'xyz')
            ->getJson('/api/oauth/callback?code=abc')
            ->assertStatus(422);
    }
}
