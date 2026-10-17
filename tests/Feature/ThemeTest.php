<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ThemeTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_theme_is_bought_once_with_kado_points_then_chosen(): void
    {
        config(['kado.themes.karbon.price' => 1000]);
        $user = User::factory()->create(['kado_points' => 1500]);
        Sanctum::actingAs($user);

        $this->getJson('/api/themes')->assertOk()
            ->assertJsonPath('data.0.key', 'base')
            ->assertJsonPath('data.0.active', true)
            ->assertJsonPath('data.1.key', 'karbon')
            ->assertJsonPath('data.1.owned', false);
        $this->putJson('/api/user/theme', ['theme' => 'karbon'])->assertStatus(422);

        $this->postJson('/api/themes/karbon/buy')->assertNoContent();
        $this->postJson('/api/themes/karbon/buy')->assertStatus(422);

        $user->refresh();
        $this->assertSame(500, $user->kado_points);
        $this->assertSame('karbon', $user->theme);
        $this->assertDatabaseHas('user_points', ['user_id' => $user->id, 'delta' => -1000, 'reason' => 'theme purchase']);
        $this->getJson('/api/user')->assertOk()->assertJsonPath('data.theme', 'karbon');

        $this->putJson('/api/user/theme', ['theme' => 'base'])->assertNoContent();
        $this->putJson('/api/user/theme', ['theme' => 'karbon'])->assertNoContent();
        $this->assertSame('karbon', $user->fresh()->theme);
    }

    public function test_a_theme_can_not_be_bought_without_enough_kado_points(): void
    {
        config(['kado.themes.karbon.price' => 1000]);
        $user = User::factory()->create(['kado_points' => 999]);
        Sanctum::actingAs($user);

        $this->postJson('/api/themes/karbon/buy')->assertStatus(422)
            ->assertJsonPath('message', 'Vous n\'avez pas assez de points Kado pour acheter ce thème.');
        $this->assertSame(999, $user->fresh()->kado_points);
        $this->postJson('/api/themes/unknown/buy')->assertNotFound();
    }
}
