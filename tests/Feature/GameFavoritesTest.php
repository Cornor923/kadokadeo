<?php

namespace Tests\Feature;

use App\Models\Game;
use App\Models\User;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class GameFavoritesTest extends TestCase
{
    use RefreshDatabase;

    public function test_favorites_are_persistent_idempotent_and_scoped_to_the_authenticated_user(): void
    {
        if (!Schema::hasTable('user_favorite_games')) {
            Schema::create('user_favorite_games', function (Blueprint $table) {
                $table->increments('id');
                $table->bigInteger('user_id')->nullable();
                $table->bigInteger('game_id')->nullable();
                $table->unique(['user_id', 'game_id']);
            });
        }

        $user = User::factory()->create();
        $otherUser = User::factory()->create();
        $game = Game::factory()->create();
        Gate::before(fn (User $viewer, string $ability, array $arguments) => $ability === 'view' && ($arguments[0] ?? null) instanceof Game && $arguments[0]->id === $game->id
                ? true
                : null);

        $this->getJson("/api/games/{$game->id}")->assertUnauthorized();
        $this->putJson("/api/games/{$game->id}/favorite", ['is_favorite' => true])->assertUnauthorized();

        DB::table('user_favorite_games')->insert(['user_id' => $otherUser->id, 'game_id' => $game->id]);

        $this->actingAs($user, 'sanctum')
            ->getJson("/api/games/{$game->id}")
            ->assertOk()
            ->assertJsonPath('data.is_favorite', false);

        $this->getJson('/api/games')->assertOk()->assertJsonPath('data.0.is_favorite', false);

        foreach ([true, true] as $isFavorite) {
            $this->putJson("/api/games/{$game->id}/favorite", [
                'is_favorite' => $isFavorite,
                'user_id' => $otherUser->id,
            ])->assertOk()->assertJsonPath('is_favorite', true);
        }

        $this->assertSame(1, DB::table('user_favorite_games')->where('user_id', $user->id)->count());
        $this->getJson("/api/games/{$game->id}")->assertOk()->assertJsonPath('data.is_favorite', true);
        $this->getJson('/api/games')->assertOk()->assertJsonPath('data.0.is_favorite', true);

        $this->putJson("/api/games/{$game->id}/favorite", ['is_favorite' => false])
            ->assertOk()
            ->assertJsonPath('is_favorite', false);

        $this->assertDatabaseMissing('user_favorite_games', ['user_id' => $user->id, 'game_id' => $game->id]);
        $this->assertDatabaseHas('user_favorite_games', ['user_id' => $otherUser->id, 'game_id' => $game->id]);
        $this->getJson("/api/games/{$game->id}")->assertOk()->assertJsonPath('data.is_favorite', false);
        $this->getJson('/api/games')->assertOk()->assertJsonPath('data.0.is_favorite', false);
    }
}
