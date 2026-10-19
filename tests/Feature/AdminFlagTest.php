<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminFlagTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_user_knows_whether_they_are_admin_but_not_whether_the_others_are(): void
    {
        $admin = User::factory()->create(['is_admin' => true]);
        $player = User::factory()->create();

        Sanctum::actingAs($admin);
        $this->getJson('/api/user')->assertOk()->assertJsonPath('data.is_admin', true);

        Sanctum::actingAs($player);
        $this->getJson('/api/user')->assertOk()->assertJsonPath('data.is_admin', false);
        $this->getJson("/api/users/{$admin->etwin_id}")->assertOk()->assertJsonMissingPath('data.is_admin');
    }
}
