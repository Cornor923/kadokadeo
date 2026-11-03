<?php

namespace Tests\Feature;

use App\Enums\UserPreference;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class UserPreferenceTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_preferences_have_their_defaults_then_change_one_by_one(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->getJson('/api/user')->assertOk()
            ->assertJsonPath('data.id', $user->id)
            ->assertJsonPath('data.preferences', [
                'notify_run_comments' => true,
                'notify_comment_replies' => true,
                'notify_comment_likes' => true,
            ]);

        $this->putJson('/api/user/preferences', ['notify_run_comments' => false])->assertOk()
            ->assertJsonPath('data.notify_run_comments', false)
            ->assertJsonPath('data.notify_comment_replies', true);
        $this->putJson('/api/user/preferences', ['notify_comment_likes' => false])->assertOk();

        $user->refresh();
        $this->assertFalse($user->prefers(UserPreference::NOTIFY_RUN_COMMENTS));
        $this->assertFalse($user->prefers(UserPreference::NOTIFY_COMMENT_LIKES));
        $this->assertTrue($user->prefers(UserPreference::NOTIFY_COMMENT_REPLIES));
    }

    public function test_only_the_known_preferences_are_saved(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->putJson('/api/user/preferences', ['notify_everything' => true])->assertStatus(422);
        $this->putJson('/api/user/preferences', ['notify_run_comments' => 'oui'])->assertStatus(422);
        $this->assertNull($user->fresh()->preferences);
    }

    // the other players do not see them (nor the id)
    public function test_the_preferences_of_another_player_are_not_shown(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs(User::factory()->create());

        $this->getJson("/api/users/{$user->etwin_id}")->assertOk()
            ->assertJsonPath('data.etwin_id', $user->etwin_id)
            ->assertJsonMissingPath('data.preferences')
            ->assertJsonMissingPath('data.id');
    }
}
