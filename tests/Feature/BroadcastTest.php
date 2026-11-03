<?php

namespace Tests\Feature;

use App\Events\AnnouncementUpdated;
use App\Events\ClanUpdated;
use App\Events\DailyScoresChanged;
use App\Events\GameScoresChanged;
use App\Events\MessageReceived;
use App\Events\MessageSent;
use App\Events\PeriodStarted;
use App\Events\RunCommentsChanged;
use App\Events\SystemMessageSent;
use App\Events\UnreadCountsChanged;
use App\Events\UserCountersChanged;
use App\Events\UserRefresh;
use App\Models\Clan;
use App\Models\DailyGame;
use App\Models\Game;
use App\Models\Message;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use App\Services\MessageService;
use App\Services\ModerationService;
use App\Services\RunService;
use App\Settings\SiteSettings;
use App\Support\Realtime;
use App\Support\RealtimeOutbox;
use Illuminate\Broadcasting\BroadcastManager;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Exceptions;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\EnablesClans;
use Tests\TestCase;

class BroadcastTest extends TestCase
{
    use EnablesClans;
    use RefreshDatabase;

    // Reverb as in production (the "null" broadcaster of the tests authorizes every channel), the channels declared again
    // on it
    private function useReverb(string $host = 'localhost', int $port = 8080): void
    {
        config([
            'broadcasting.default' => 'reverb',
            'broadcasting.connections.reverb.key' => 'test-key',
            'broadcasting.connections.reverb.secret' => 'test-secret',
            'broadcasting.connections.reverb.app_id' => 'test',
            'broadcasting.connections.reverb.options.host' => $host,
            'broadcasting.connections.reverb.options.port' => $port,
            'broadcasting.connections.reverb.options.scheme' => 'http',
            'broadcasting.connections.reverb.options.useTLS' => false,
        ]);
        app(BroadcastManager::class)->forgetDrivers();
        require base_path('routes/channels.php');
    }

    private function authorize(User $user, string $channel)
    {
        Sanctum::actingAs($user);

        return $this->postJson('/api/broadcasting/auth', ['socket_id' => '1234.5678', 'channel_name' => $channel]);
    }

    private function encryptRun(array $request): array
    {
        $json = json_encode($request);
        $aesKey = random_bytes(16);
        $iv = random_bytes(16);
        $cipher = openssl_encrypt($json, 'aes-128-ctr', $aesKey, OPENSSL_RAW_DATA, $iv);
        openssl_public_encrypt(base64_encode($aesKey), $encryptedKey, app(RunService::class)->getPublicKey());

        return [
            'payload' => base64_encode($iv.$cipher),
            'key' => base64_encode($encryptedKey),
            'sign' => base64_encode(hash_hmac('sha256', $json, $aesKey, true)),
        ];
    }

    private function finish(Run $run, int $score)
    {
        Sanctum::actingAs($run->user);

        return $this->postJson("/api/runs/{$run->id}/finish", $this->encryptRun([
            'run_id' => $run->id,
            'score' => $score,
            'timestamp' => now()->timestamp,
            'replay' => null,
            'data' => [],
            'ac' => 0,
        ]))->assertOk();
    }

    public function test_the_players_join_their_own_channels_only(): void
    {
        $this->useReverb();
        [$player, $other] = User::factory()->count(2)->create();
        $clan = Clan::factory()->withLeader($player)->create();

        $this->authorize($player, "private-App.Models.User.{$player->id}")->assertOk()->assertJsonStructure(['auth']);
        $this->authorize($player, "private-App.Models.User.{$other->id}")->assertForbidden();
        $this->authorize($player, "private-clans.{$clan->id}")->assertOk();
        $this->authorize($other, "private-clans.{$clan->id}")->assertForbidden();
        // the clans closed: nobody
        $this->setClansEnabled(false);
        $this->authorize($player, "private-clans.{$clan->id}")->assertForbidden();
        // the comments of a replay: the players who can watch it
        $replay = Run::factory()->for($player)->create(['replay' => 'replay-data']);
        $noReplay = Run::factory()->for($player)->create(['replay' => null]);
        $this->authorize($other, "private-runs.{$replay->id}")->assertOk();
        $this->authorize($other, "private-runs.{$noReplay->id}")->assertForbidden();
        $this->authorize($other, 'private-runs.01aaaaaaaaaaaaaaaaaaaaaaaa')->assertForbidden();

        $player->update(['banned_at' => now()]);
        $this->authorize($player, "private-App.Models.User.{$player->id}")->assertForbidden();

        $this->app['auth']->forgetGuards();
        $this->postJson('/api/broadcasting/auth', ['socket_id' => '1234.5678', 'channel_name' => "private-App.Models.User.{$player->id}"])->assertUnauthorized();
    }

    public function test_the_page_knows_where_to_connect(): void
    {
        $this->assertNull(Realtime::clientConfig());

        $this->useReverb();
        config(['broadcasting.connections.reverb.client.port' => '443']);
        $this->assertSame(['key' => 'test-key', 'host' => null, 'port' => 443, 'scheme' => null], Realtime::clientConfig());

        // the port given by Katal: where Reverb listens and this server sends the events, not where the browsers connect
        $_SERVER['WS_PORT'] = $_ENV['WS_PORT'] = '6001';
        try {
            $broadcasting = require config_path('broadcasting.php');
            $reverb = require config_path('reverb.php');
        } finally {
            unset($_SERVER['WS_PORT'], $_ENV['WS_PORT']);
        }
        $this->assertSame('6001', $reverb['servers']['reverb']['port']);
        $this->assertSame('6001', $broadcasting['connections']['reverb']['options']['port']);
        $this->assertNull($broadcasting['connections']['reverb']['client']['port']);
    }

    // the pages of the replay: its comments again (not for the one who wrote it), its likes counted
    public function test_the_comments_of_a_replay_are_followed(): void
    {
        Event::fake([RunCommentsChanged::class]);
        [$player, $viewer] = User::factory()->count(2)->create();
        $run = Run::factory()->for($player)->create(['replay' => 'replay-data', 'replay_frames' => 3200]);

        Sanctum::actingAs($viewer);
        $id = $this->postJson("/api/runs/{$run->id}/comments", ['frame' => 64, 'content' => 'Joli'])->assertCreated()->json('data.id');
        Event::assertDispatched(RunCommentsChanged::class, fn (RunCommentsChanged $e) => $e->broadcastOn()->name === "private-runs.{$run->id}"
            && $e->broadcastWith() === ['comment_id' => $id, 'by' => $viewer->etwin_id, 'likes_count' => null]);

        Sanctum::actingAs($player);
        $this->putJson("/api/run-comments/{$id}/like")->assertOk();
        $this->putJson("/api/run-comments/{$id}/like")->assertOk();
        Event::assertDispatched(RunCommentsChanged::class, fn (RunCommentsChanged $e) => $e->broadcastWith()['likes_count'] === 1);
        $this->deleteJson("/api/run-comments/{$id}")->assertNoContent();
        // created, liked once (the second like changes nothing), deleted
        Event::assertDispatchedTimes(RunCommentsChanged::class, 3);
    }

    // a private message: the recipient (his badge, a toast), the other tabs of the sender, then the badge when it is read
    public function test_the_private_messages_are_sent_at_once(): void
    {
        Event::fake([MessageReceived::class, MessageSent::class, UnreadCountsChanged::class, SystemMessageSent::class]);
        [$sender, $recipient] = User::factory()->count(2)->create();

        Sanctum::actingAs($sender);
        $id = $this->postJson('/api/messages', ['to' => $recipient->display_name, 'subject' => 'Salut', 'body' => 'Coucou'])
            ->assertCreated()->json('data.id');
        Event::assertDispatched(MessageReceived::class, fn (MessageReceived $e) => $e->broadcastOn()->name === "private-App.Models.User.{$recipient->id}"
            && $e->broadcastWith()['message']['subject'] === 'Salut'
            && $e->broadcastWith()['message']['sender']['display_name'] === $sender->display_name
            && $e->broadcastWith()['unread'] === ['messages' => 1, 'notifications' => 0]);
        Event::assertDispatched(MessageSent::class, fn (MessageSent $e) => $e->broadcastOn()->name === "private-App.Models.User.{$sender->id}");

        Sanctum::actingAs($recipient);
        $this->getJson("/api/messages/{$id}")->assertOk();
        $this->getJson("/api/messages/{$id}")->assertOk();
        Event::assertDispatchedTimes(UnreadCountsChanged::class, 1);

        // to everyone: one event for all
        app(MessageService::class)->systemToAll('Info', 'Bonjour à tous');
        Event::assertDispatchedTimes(SystemMessageSent::class, 1);
        Event::assertDispatchedTimes(MessageReceived::class, 1);
        $this->assertSame(2, Message::query()->where('subject', 'Info')->count());
    }

    public function test_the_announcement_saved_in_the_admin_is_sent(): void
    {
        Event::fake([AnnouncementUpdated::class]);

        $this->setSettings(SiteSettings::class, ['announcement_enabled' => true, 'announcement_level' => 'success', 'announcement_content' => 'Nouveau jeu **ce soir**']);

        Event::assertDispatched(AnnouncementUpdated::class, fn (AnnouncementUpdated $e) => $e->broadcastOn()->name === 'site'
            && $e->broadcastWith()['announcement']['level'] === 'success'
            && str_contains($e->broadcastWith()['announcement']['html'], '<strong>ce soir</strong>'));
    }

    // the leaderboards change only for a run in the top 10 of its league or a record (and a run taken out)
    public function test_the_leaderboards_are_told_of_the_runs_in_their_top(): void
    {
        Event::fake([GameScoresChanged::class, DailyScoresChanged::class]);
        $game = Game::factory()->create();
        $period = Period::factory()->create();
        $inPeriod = fn () => Run::factory()->for($game)->state(['period_id' => $period->id]);
        foreach (range(1, 10) as $score) {
            $inPeriod()->create(['score' => 100 + $score]);
        }

        $low = $inPeriod()->create(['score' => null, 'completed_at' => null]);
        $this->finish($low, 50);
        Event::assertNotDispatched(GameScoresChanged::class);

        $high = $inPeriod()->create(['score' => null, 'completed_at' => null]);
        $this->finish($high, 105);
        Event::assertDispatched(GameScoresChanged::class, fn (GameScoresChanged $e) => $e->broadcastOn()->name === "games.{$game->id}"
            && $e->broadcastWith()['period_id'] === $period->id
            && $e->broadcastWith()['world_best'] === false);

        $record = $inPeriod()->create(['score' => null, 'completed_at' => null]);
        $this->finish($record, 500);
        Event::assertDispatched(GameScoresChanged::class, fn (GameScoresChanged $e) => $e->broadcastWith()['world_best'] === true);

        // the daily game: its top 10
        $daily = DailyGame::create(['day' => today()->toDateString(), 'game_id' => $game->id, 'seed' => 'daily-seed', 'contract_score' => 0, 'contract_points' => 0]);
        $dailyRun = $inPeriod()->create(['score' => null, 'completed_at' => null, 'daily_game_id' => $daily->id]);
        $this->finish($dailyRun, 20);
        Event::assertDispatched(DailyScoresChanged::class, fn (DailyScoresChanged $e) => $e->broadcastOn()->name === 'daily');

        // taken out: the leaderboards, the stars of the player
        Event::fake([GameScoresChanged::class, UserRefresh::class]);
        app(RunService::class)->flagAsCheat($record->fresh());
        Event::assertDispatched(GameScoresChanged::class);
        Event::assertDispatched(UserRefresh::class, fn (UserRefresh $e) => $e->broadcastOn()->name === "private-App.Models.User.{$record->user_id}");
    }

    // the Kado points and the games of the player, changed through the model or by a query
    public function test_the_counters_of_the_player_are_sent(): void
    {
        $user = User::factory()->create(['kado_points' => 100]);
        $admin = User::factory()->create(['is_admin' => true]);
        Event::fake([UserCountersChanged::class, UserRefresh::class]);

        $user->increment('kado_points', 50);
        Event::assertDispatchedTimes(UserCountersChanged::class, 1);
        $event = Event::dispatched(UserCountersChanged::class)->first()[0];
        $this->assertSame(150, $event->broadcastWith()['kado_points']);

        app(ModerationService::class)->adjustKadoPoints($user, 10, $admin);
        app(ModerationService::class)->adjustGames($user, ['kado_games' => 2]);
        Event::assertDispatchedTimes(UserCountersChanged::class, 3);

        // nothing for the other columns
        $user->update(['theme' => 'karbon']);
        Event::assertDispatchedTimes(UserCountersChanged::class, 3);

        $this->artisan('kado:reset-daily-games')->assertSuccessful();
        Event::assertDispatched(UserRefresh::class, fn (UserRefresh $e) => $e->broadcastOn()->name === 'site');
    }

    // Reverb down: the action is done, the error reported once, nothing more tried for a while
    public function test_a_reverb_that_does_not_answer_does_not_break_the_actions(): void
    {
        $this->withDefer();
        $this->useReverb('127.0.0.1', 1);
        Exceptions::fake();
        [$sender, $recipient] = User::factory()->count(2)->create();

        Sanctum::actingAs($sender);
        // (two events: to the recipient and to the sender)
        $this->postJson('/api/messages', ['to' => $recipient->display_name, 'subject' => 'Salut', 'body' => 'Coucou'])->assertCreated();
        $this->postJson('/api/messages', ['to' => $recipient->display_name, 'subject' => 'Re', 'body' => 'Encore'])->assertCreated();

        $this->assertSame(2, Message::query()->count());
        Exceptions::assertReportedCount(1);
        Exceptions::assertReported(\Illuminate\Broadcasting\BroadcastException::class);

        $this->travel(RealtimeOutbox::DOWN_SECONDS + 1)->seconds();
        $this->postJson('/api/messages', ['to' => $recipient->display_name, 'subject' => 'Re', 'body' => 'Encore'])->assertCreated();
        Exceptions::assertReportedCount(2);
    }

    // the events of a request: after its response, each once (the parts of a clan together)
    public function test_the_events_of_a_request_are_sent_after_it_once(): void
    {
        $this->withDefer();
        Event::fake([UnreadCountsChanged::class, ClanUpdated::class, GameScoresChanged::class, MessageSent::class]);
        [$user, $other] = User::factory()->count(2)->create();
        $message = Message::query()->create(['sender_id' => $user->id, 'recipient_id' => $other->id, 'subject' => 'Salut', 'body' => 'Coucou']);

        DB::transaction(function () use ($user, $message) {
            Realtime::send(new UnreadCountsChanged($user));
            Realtime::send(new ClanUpdated(7, [ClanUpdated::MEMBERS]));
            Realtime::send(new UnreadCountsChanged($user->id));
            Realtime::send(new ClanUpdated(7, [ClanUpdated::STATUS, ClanUpdated::MEMBERS]));
            Realtime::send(new ClanUpdated(8, [ClanUpdated::CLAN]));
            Realtime::send(new GameScoresChanged(1, 2, 3));
            Realtime::send(new GameScoresChanged(1, 2, 4, worldBest: true));
            Realtime::send(new MessageSent($message));
            Realtime::send(new MessageSent($message));
        });
        Event::assertNothingDispatched();

        defer()->invoke();
        Event::assertDispatchedTimes(UnreadCountsChanged::class, 1);
        Event::assertDispatchedTimes(ClanUpdated::class, 2);
        Event::assertDispatched(ClanUpdated::class, fn (ClanUpdated $e) => $e->broadcastOn()->name === 'private-clans.7'
            && $e->broadcastWith() === ['parts' => [ClanUpdated::MEMBERS, ClanUpdated::STATUS]]);
        // two leagues: every league
        Event::assertDispatchedTimes(GameScoresChanged::class, 1);
        Event::assertDispatched(GameScoresChanged::class, fn (GameScoresChanged $e) => $e->broadcastWith()['league_id'] === null
            && $e->broadcastWith()['world_best'] === true);
        // (not merged)
        Event::assertDispatchedTimes(MessageSent::class, 2);

        // rolled back: nothing
        Event::fake([UnreadCountsChanged::class]);
        try {
            DB::transaction(function () use ($user) {
                Realtime::send(new UnreadCountsChanged($user));
                throw new \RuntimeException('rollback');
            });
        } catch (\RuntimeException) {
        }
        defer()->invoke();
        Event::assertNotDispatched(UnreadCountsChanged::class);
    }

    // a new period: in the event, the same for everyone
    public function test_the_new_period_is_in_its_event(): void
    {
        Event::fake([PeriodStarted::class]);
        $period = Period::factory()->create(['start_at' => now()->subDay(), 'end_at' => now()->addDays(10)]);

        Realtime::send(new PeriodStarted());

        Event::assertDispatched(PeriodStarted::class, fn (PeriodStarted $e) => $e->broadcastWith()['period']['id'] === $period->id);
    }
}
