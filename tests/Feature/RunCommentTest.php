<?php

namespace Tests\Feature;

use App\Enums\ReportStatus;
use App\Http\Resources\RunResource;
use App\Models\DailyGame;
use App\Models\Report;
use App\Models\Run;
use App\Models\RunComment;
use App\Models\User;
use App\Settings\ReplaySettings;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RunCommentTest extends TestCase
{
    use RefreshDatabase;

    private User $player;

    private User $viewer;

    private Run $run;

    protected function setUp(): void
    {
        parent::setUp();
        [$this->player, $this->viewer] = User::factory()->count(2)->create();
        $this->run = Run::factory()->for($this->player)->create(['replay' => 'replay-data', 'replay_frames' => 3200]);
    }

    private function comment(User $author, int $frame = 64, string $content = 'Joli coup', ?int $parent = null): int
    {
        Sanctum::actingAs($author);

        return $this->postJson("/api/runs/{$this->run->id}/comments", ['frame' => $frame, 'content' => $content, 'parent_id' => $parent])
            ->assertCreated()
            ->json('data.id');
    }

    // the comments come in the order of the replay, with the answers, the likes of the viewer and the limits of the page
    public function test_a_player_comments_a_replay_and_answers(): void
    {
        $late = $this->comment($this->viewer, 2000, "Sur\n deux   lignes");
        $early = $this->comment($this->player, 100);
        $answer = $this->comment($this->viewer, 5, 'Merci !', $early);

        $this->assertSame(100, RunComment::find($answer)->frame);
        $this->assertSame('Sur deux lignes', RunComment::find($late)->content);
        $this->assertSame(3, $this->run->refresh()->comments_count);
        $this->assertSame(1, RunComment::find($early)->replies_count);

        Sanctum::actingAs($this->viewer);
        $this->putJson("/api/run-comments/{$early}/like")->assertOk()->assertJsonPath('data.likes_count', 1);
        $this->getJson("/api/runs/{$this->run->id}/comments")
            ->assertOk()
            ->assertJsonPath('data.0.id', $early)
            ->assertJsonPath('data.0.liked', true)
            ->assertJsonPath('data.0.author.display_name', $this->player->display_name)
            ->assertJsonPath('data.1.id', $answer)
            ->assertJsonPath('data.1.parent_id', $early)
            ->assertJsonPath('data.1.is_own', true)
            ->assertJsonPath('data.2.id', $late)
            ->assertJsonPath('viewer.can_comment', true)
            ->assertJsonPath('limits.max_length', 280)
            ->assertJsonPath('limits.view_after_seconds', 10);

        // the replay page knows the counters and the length of the replay before loading the game
        $data = RunResource::make($this->run->refresh())->withReplay()->resolve(request());
        $this->assertSame([3, 3200], [$data['comments_count'], $data['replay_frames']]);
    }

    public function test_the_comments_are_checked(): void
    {
        Sanctum::actingAs($this->viewer);
        $url = "/api/runs/{$this->run->id}/comments";
        $this->postJson($url, ['frame' => 10, 'content' => str_repeat('a', 281)])->assertStatus(422)->assertJsonValidationErrors(['content']);
        $this->postJson($url, ['frame' => -1, 'content' => 'a'])->assertStatus(422)->assertJsonValidationErrors(['frame']);
        $this->postJson($url, ['frame' => 10, 'content' => "  \n "])->assertStatus(422);

        // after the end of the replay: at its end
        $id = $this->comment($this->viewer, 99999);
        $this->assertSame(3200, RunComment::find($id)->frame);

        // no answer to an answer, nor to a comment of another replay
        $answer = $this->comment($this->player, 0, 'Réponse', $id);
        Sanctum::actingAs($this->viewer);
        $this->postJson($url, ['frame' => 0, 'content' => 'a', 'parent_id' => $answer])->assertStatus(422)->assertJsonPath('message', 'On ne peut pas répondre à une réponse.');
        $other = RunComment::factory()->create();
        $this->postJson($url, ['frame' => 0, 'content' => 'a', 'parent_id' => $other->id])->assertStatus(422);
    }

    public function test_the_limits_come_from_the_settings(): void
    {
        $settings = app(ReplaySettings::class);
        $settings->comments_max_per_user_per_run = 2;
        $settings->save();

        $this->comment($this->viewer);
        $first = $this->comment($this->viewer);
        $this->deleteJson("/api/run-comments/{$first}")->assertNoContent();
        $this->postJson("/api/runs/{$this->run->id}/comments", ['frame' => 1, 'content' => 'Encore'])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Vous avez déjà beaucoup commenté ce replay.');

        $settings->comments_enabled = false;
        $settings->save();
        Sanctum::actingAs($this->player);
        $this->postJson("/api/runs/{$this->run->id}/comments", ['frame' => 1, 'content' => 'Fermé'])->assertStatus(422);
        $this->getJson("/api/runs/{$this->run->id}/comments")->assertJsonPath('viewer.can_comment', false);
    }

    // the same rule as the replay: the replays of today's daily game are hidden from the other players
    public function test_only_the_players_who_can_watch_the_replay_read_its_comments(): void
    {
        $this->getJson("/api/runs/{$this->run->id}/comments")->assertUnauthorized();

        $daily = DailyGame::create(['day' => today(), 'game_id' => $this->run->game_id, 'seed' => 'daily', 'contract_score' => 0, 'contract_points' => 0]);
        $this->run->update(['daily_game_id' => $daily->id]);
        Sanctum::actingAs($this->viewer);
        $this->getJson("/api/runs/{$this->run->id}/comments")->assertForbidden();
        $this->postJson("/api/runs/{$this->run->id}/comments", ['frame' => 1, 'content' => 'a'])->assertForbidden();
        Sanctum::actingAs($this->player);
        $this->getJson("/api/runs/{$this->run->id}/comments")->assertOk();
    }

    public function test_the_author_edits_the_author_the_player_and_the_admins_delete(): void
    {
        $id = $this->comment($this->viewer);
        $stranger = User::factory()->create();

        Sanctum::actingAs($stranger);
        $this->patchJson("/api/run-comments/{$id}", ['content' => 'Pirate'])->assertStatus(422);
        $this->deleteJson("/api/run-comments/{$id}")->assertStatus(422);

        Sanctum::actingAs($this->viewer);
        $this->patchJson("/api/run-comments/{$id}", ['content' => 'Corrigé'])->assertNoContent();
        $this->assertSame('Corrigé', RunComment::find($id)->content);
        $this->assertNotNull(RunComment::find($id)->edited_at);

        // the player of the run deletes the comments of his replay
        Sanctum::actingAs($this->player);
        $this->deleteJson("/api/run-comments/{$id}")->assertNoContent();
        $this->assertSoftDeleted('run_comments', ['id' => $id, 'deleted_by' => $this->player->id]);
        $this->assertSame(0, $this->run->refresh()->comments_count);
        $this->patchJson("/api/run-comments/{$id}", ['content' => 'Corrigé'])->assertNotFound();

        $other = $this->comment($this->viewer);
        Sanctum::actingAs(User::factory()->create(['is_admin' => true]));
        $this->deleteJson("/api/run-comments/{$other}")->assertNoContent();
    }

    // a deleted comment stays (without its text) while it has answers
    public function test_a_deleted_comment_with_answers_stays(): void
    {
        $parent = $this->comment($this->viewer);
        $lonely = $this->comment($this->viewer, 200);
        $this->comment($this->player, 0, 'Réponse', $parent);
        Sanctum::actingAs($this->viewer);
        $this->deleteJson("/api/run-comments/{$parent}")->assertNoContent();
        $this->deleteJson("/api/run-comments/{$lonely}")->assertNoContent();

        $this->getJson("/api/runs/{$this->run->id}/comments")
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.id', $parent)
            ->assertJsonPath('data.0.is_deleted', true)
            ->assertJsonPath('data.0.content', null);
    }

    public function test_a_like_counts_once(): void
    {
        $id = $this->comment($this->player);
        Sanctum::actingAs($this->viewer);
        $this->putJson("/api/run-comments/{$id}/like")->assertJsonPath('data.likes_count', 1);
        $this->putJson("/api/run-comments/{$id}/like")->assertJsonPath('data.likes_count', 1);
        $this->deleteJson("/api/run-comments/{$id}/like")->assertJsonPath('data.likes_count', 0);
        $this->deleteJson("/api/run-comments/{$id}/like")->assertJsonPath('data.likes_count', 0);

        // not his own
        Sanctum::actingAs($this->player);
        $this->putJson("/api/run-comments/{$id}/like")->assertStatus(422);
    }

    // one report by player, not on his own comment; deleting the comment closes its reports
    public function test_a_comment_is_reported(): void
    {
        $id = $this->comment($this->player);
        Sanctum::actingAs($this->viewer);
        $this->postJson("/api/run-comments/{$id}/report", ['reason' => 'nope'])->assertStatus(422)->assertJsonValidationErrors(['reason']);
        $this->postJson("/api/run-comments/{$id}/report", ['reason' => 'abuse', 'details' => 'Insulte'])->assertNoContent();
        $this->postJson("/api/run-comments/{$id}/report", ['reason' => 'spam'])->assertNoContent();
        $this->assertSame(1, Report::count());
        $report = Report::first();
        $this->assertSame('run_comment', $report->reportable_type);
        $this->assertSame($this->player->id, $report->reported_user_id);
        $this->assertSame(ReportStatus::OPEN, $report->status);

        Sanctum::actingAs($this->player);
        $this->postJson("/api/run-comments/{$id}/report", ['reason' => 'spam'])->assertStatus(422);
        $this->deleteJson("/api/run-comments/{$id}")->assertNoContent();
        $this->assertSame(ReportStatus::ACTIONED, $report->refresh()->status);
    }

    // one view by player, after the page measured the time watched; his own replay is not counted
    public function test_a_view_counts_once_by_player(): void
    {
        Sanctum::actingAs($this->viewer);
        $this->postJson("/api/runs/{$this->run->id}/view")->assertNoContent();
        $this->postJson("/api/runs/{$this->run->id}/view")->assertNoContent();
        Sanctum::actingAs($this->player);
        $this->postJson("/api/runs/{$this->run->id}/view")->assertNoContent();

        $this->assertSame(1, $this->run->refresh()->views_count);
        $this->assertDatabaseCount('run_views', 1);
    }
}
