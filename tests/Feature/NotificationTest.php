<?php

namespace Tests\Feature;

use App\Enums\NotificationType;
use App\Events\NotificationReceived;
use App\Events\UnreadCountsChanged;
use App\Models\Run;
use App\Models\User;
use App\Models\UserNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class NotificationTest extends TestCase
{
    use RefreshDatabase;

    private User $player;

    private User $viewer;

    private User $third;

    private Run $run;

    protected function setUp(): void
    {
        parent::setUp();
        [$this->player, $this->viewer, $this->third] = User::factory()->count(3)->create();
        $this->run = Run::factory()->for($this->player)->create(['replay' => 'replay-data', 'replay_frames' => 3200]);
    }

    private function comment(User $author, ?int $parent = null): int
    {
        Sanctum::actingAs($author);

        return $this->postJson("/api/runs/{$this->run->id}/comments", ['frame' => 64, 'content' => 'Joli coup', 'parent_id' => $parent])
            ->assertCreated()
            ->json('data.id');
    }

    private function notificationsOf(User $user)
    {
        return UserNotification::query()->where('user_id', $user->id)->orderBy('id')->get();
    }

    // the player of the run is told, at once; his own comments tell him nothing
    public function test_a_comment_notifies_the_player_of_the_run(): void
    {
        Event::fake([NotificationReceived::class]);

        $comment = $this->comment($this->viewer);
        $this->comment($this->player);

        $notifications = $this->notificationsOf($this->player);
        $this->assertCount(1, $notifications);
        $this->assertSame(NotificationType::RUN_COMMENT, $notifications[0]->type);
        $this->assertSame($this->viewer->id, $notifications[0]->actor_id);
        Event::assertDispatched(NotificationReceived::class, fn (NotificationReceived $e) => $e->broadcastOn()->name === "private-App.Models.User.{$this->player->id}"
            && $e->broadcastWith()['unread']['notifications'] === 1
            && $e->broadcastWith()['notification']['comment']['id'] === $comment);

        Sanctum::actingAs($this->player);
        $this->getJson('/api/notifications')->assertOk()
            ->assertJsonPath('data.0.type', 'run_comment')
            ->assertJsonPath('data.0.actor.display_name', $this->viewer->display_name)
            ->assertJsonPath('data.0.run.id', $this->run->id)
            ->assertJsonPath('data.0.comment.id', $comment)
            ->assertJsonPath('data.0.read', false)
            ->assertJsonPath('unread.notifications', 1);
    }

    // the author of the comment answered, and the player of the run, once each
    public function test_an_answer_notifies_the_author_of_the_comment_once(): void
    {
        $byViewer = $this->comment($this->viewer);
        $byPlayer = $this->comment($this->player);

        $answer = $this->comment($this->third, $byViewer);
        $this->assertSame(NotificationType::COMMENT_REPLY, UserNotification::query()->where('user_id', $this->viewer->id)->where('comment_id', $answer)->sole()->type);
        $this->assertSame(NotificationType::RUN_COMMENT, UserNotification::query()->where('user_id', $this->player->id)->where('comment_id', $answer)->sole()->type);

        // the player of the run answered: told once, of the answer
        $answer = $this->comment($this->third, $byPlayer);
        $this->assertSame(NotificationType::COMMENT_REPLY, UserNotification::query()->where('user_id', $this->player->id)->where('comment_id', $answer)->sole()->type);

        // the player answers: only the author of the comment
        $answer = $this->comment($this->player, $byViewer);
        $this->assertSame(1, UserNotification::query()->where('comment_id', $answer)->count());
        $this->assertSame($this->viewer->id, UserNotification::query()->where('comment_id', $answer)->value('user_id'));
    }

    public function test_the_preferences_turn_the_notifications_off(): void
    {
        $this->player->update(['preferences' => ['notify_run_comments' => false]]);
        $this->viewer->update(['preferences' => ['notify_comment_replies' => false, 'notify_comment_likes' => false]]);

        $comment = $this->comment($this->viewer);
        $this->comment($this->third, $comment);
        Sanctum::actingAs($this->third);
        $this->putJson("/api/run-comments/{$comment}/like")->assertOk();

        $this->assertCount(0, $this->notificationsOf($this->player));
        $this->assertCount(0, $this->notificationsOf($this->viewer));
    }

    // one notification for all the likes of a comment: the last one who liked it, unread again and on top at each like
    public function test_the_likes_of_a_comment_are_one_notification(): void
    {
        $comment = $this->comment($this->viewer);

        Sanctum::actingAs($this->player);
        $this->putJson("/api/run-comments/{$comment}/like")->assertOk();
        $notification = UserNotification::query()->where('user_id', $this->viewer->id)->sole();
        $this->assertSame(NotificationType::COMMENT_LIKES, $notification->type);
        $this->assertSame([1, $this->player->id], [$notification->count, $notification->actor_id]);

        Sanctum::actingAs($this->viewer);
        $this->postJson('/api/notifications/read')->assertOk()->assertJsonPath('data.notifications', 0);

        $this->travel(5)->minutes();
        Event::fake([NotificationReceived::class]);
        Sanctum::actingAs($this->third);
        $this->putJson("/api/run-comments/{$comment}/like")->assertOk();
        $liked = UserNotification::query()->where('user_id', $this->viewer->id)->sole();
        $this->assertSame([2, $this->third->id, null], [$liked->count, $liked->actor_id, $liked->read_at]);
        $this->assertTrue($liked->updated_at->gt($notification->updated_at));
        Event::assertDispatched(NotificationReceived::class, fn (NotificationReceived $e) => $e->broadcastWith()['notification']['count'] === 2);

        // taken back: counted again, the last one left; gone with the last like
        $this->deleteJson("/api/run-comments/{$comment}/like")->assertOk();
        $unliked = UserNotification::query()->where('user_id', $this->viewer->id)->sole();
        $this->assertSame([1, $this->player->id], [$unliked->count, $unliked->actor_id]);
        Sanctum::actingAs($this->player);
        $this->deleteJson("/api/run-comments/{$comment}/like")->assertOk();
        $this->assertCount(0, $this->notificationsOf($this->viewer));
    }

    public function test_a_deleted_comment_takes_its_notifications_away(): void
    {
        Event::fake([UnreadCountsChanged::class]);
        $comment = $this->comment($this->viewer);
        $this->assertCount(1, $this->notificationsOf($this->player));

        $this->deleteJson("/api/run-comments/{$comment}")->assertNoContent();

        $this->assertCount(0, $this->notificationsOf($this->player));
        Event::assertDispatched(UnreadCountsChanged::class, fn (UnreadCountsChanged $e) => $e->broadcastOn()->name === "private-App.Models.User.{$this->player->id}");
    }

    public function test_the_notifications_are_read_and_deleted_by_their_player_only(): void
    {
        $this->comment($this->viewer);
        $this->comment($this->third);
        [$first, $second] = $this->notificationsOf($this->player);

        Sanctum::actingAs($this->viewer);
        $this->deleteJson("/api/notifications/{$first->id}")->assertNotFound();
        $this->getJson('/api/notifications')->assertOk()->assertJsonCount(0, 'data');

        Sanctum::actingAs($this->player);
        $this->getJson('/api/notifications/unread')->assertOk()->assertJsonPath('data.notifications', 2);
        $this->postJson('/api/notifications/read')->assertOk()->assertJsonPath('data.notifications', 0);
        $this->deleteJson("/api/notifications/{$first->id}")->assertNoContent();
        $this->getJson('/api/notifications')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $second->id);
        $this->deleteJson('/api/notifications')->assertNoContent();
        $this->assertCount(0, $this->notificationsOf($this->player));
    }

    public function test_the_notifications_are_removed_two_months_after_their_last_change(): void
    {
        $this->comment($this->viewer);
        $this->travel(UserNotification::KEEP_MONTHS)->months();
        $this->travel(1)->days();
        $this->comment($this->third);

        $this->artisan('model:prune', ['--model' => [UserNotification::class]])->assertSuccessful();

        $this->assertSame([$this->third->id], $this->notificationsOf($this->player)->pluck('actor_id')->all());
    }
}
