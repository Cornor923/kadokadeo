<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PersonalAccessTokenTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_last_use_of_a_token_is_written_every_five_minutes_only(): void
    {
        $user = User::factory()->create();
        $plain = $user->createToken('kadokadeo')->plainTextToken;
        $token = $user->tokens()->sole();
        $call = function () use ($plain) {
            $this->app['auth']->forgetGuards();
            $this->withToken($plain)->getJson('/api/user')->assertOk();
        };

        $this->travelTo(now()->startOfMinute());
        $call();
        $first = $token->fresh()->last_used_at;
        $this->assertNotNull($first);

        $this->travel(2)->minutes();
        $call();
        $this->assertEquals($first, $token->fresh()->last_used_at);

        $this->travel(4)->minutes();
        $call();
        $this->assertTrue($token->fresh()->last_used_at->gt($first));
    }
}
