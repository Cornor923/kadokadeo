<?php

namespace Tests\Feature;

use App\Enums\ClanRole;
use App\Enums\NotificationType;
use App\Events\ClanForumUpdated;
use App\Events\ClanToast;
use App\Events\ClanUpdated;
use App\Models\Clan;
use App\Models\ClanMission;
use App\Models\Game;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use App\Models\UserNotification;
use App\Services\ClanMissionService;
use App\Services\ClanRunService;
use App\Services\ClanWarService;
use App\Settings\ClanSettings;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\EnablesClans;
use Tests\Concerns\PlayableGames;
use Tests\TestCase;

class ClanNotificationTest extends TestCase
{
    use EnablesClans, PlayableGames, RefreshDatabase;

    // day 2 of the period
    private function period(): Period
    {
        return Period::factory()->create(['start_at' => now()->subDay()->startOfDay(), 'end_at' => now()->addDays(12)->endOfDay()]);
    }

    // a clan run: the action asked on the clan pages, then a run of the game ended with this score
    private function playClanRun(User $user, Game $game, Period $period, int $score): ?array
    {
        $run = Run::factory()->for($game)->for($user)->for($period)->create(['score' => 0, 'completed_at' => null]);
        app(ClanRunService::class)->bindRun($run);
        $run->update(['score' => $score, 'completed_at' => now()]);

        return app(ClanRunService::class)->handleRunCompleted($run->fresh());
    }

    private function typesOf(User $user): array
    {
        return UserNotification::query()->where('user_id', $user->id)->pluck('type')->map->value->all();
    }

    // the leader and the right hands (who can answer it), until someone answers it; the player accepted is told
    public function test_the_managers_are_notified_of_an_application(): void
    {
        $this->period();
        $leader = User::factory()->create();
        $rightHand = User::factory()->create();
        $member = User::factory()->create();
        $player = User::factory()->create(['kado_points' => 1000]);
        $clan = Clan::factory()->withLeader($leader)->create();
        $clan->members()->create(['user_id' => $rightHand->id, 'role' => ClanRole::RIGHT_HAND]);
        $clan->members()->create(['user_id' => $member->id]);
        $apply = function () use ($player, $clan) {
            Sanctum::actingAs($player);

            return $this->postJson("/api/clans/{$clan->id}/applications")->assertCreated()->json('data.id');
        };

        Event::fake([ClanUpdated::class]);
        $refused = $apply();
        $this->assertSame(['clan_application'], $this->typesOf($leader));
        $this->assertSame(['clan_application'], $this->typesOf($rightHand));
        $this->assertSame([], $this->typesOf($member));
        Event::assertDispatched(ClanUpdated::class, fn (ClanUpdated $e) => $e->broadcastOn()->name === "private-clans.{$clan->id}");
        Sanctum::actingAs($rightHand);
        $this->postJson("/api/clan-applications/{$refused}/refuse")->assertNoContent();
        $this->assertSame([], $this->typesOf($leader));
        // the player is told (his Kado points given back)
        $this->assertSame(['clan_refused'], $this->typesOf($player));
        UserNotification::query()->where('user_id', $player->id)->delete();

        $cancelled = $apply();
        $this->deleteJson("/api/clan-applications/{$cancelled}")->assertNoContent();
        $this->assertSame([], $this->typesOf($rightHand));

        $accepted = $apply();
        Sanctum::actingAs($leader);
        $this->postJson("/api/clan-applications/{$accepted}/accept")->assertNoContent();
        $this->assertSame([], $this->typesOf($leader));
        $this->assertSame([], $this->typesOf($rightHand));
        $notification = UserNotification::query()->where('user_id', $player->id)->sole();
        $this->assertSame([NotificationType::CLAN_ACCEPTED, $clan->id, $leader->id], [$notification->type, $notification->clan_id, $notification->actor_id]);

        Sanctum::actingAs($player);
        $this->getJson('/api/notifications')->assertOk()
            ->assertJsonPath('data.0.type', 'clan_accepted')
            ->assertJsonPath('data.0.clan.name', $clan->name);
    }

    // a defense won and a step done: a toast for the clan, its pages told what changed
    public function test_the_members_see_the_feats_of_their_clan(): void
    {
        ClanSettings::fake(['bonus_chance' => 0]);
        $period = $this->period();
        $attacker = User::factory()->create();
        $defender = User::factory()->create();
        $clanA = Clan::factory()->withLeader($attacker)->create();
        $clanB = Clan::factory()->withLeader($defender)->create();
        $game = Game::factory()->create();
        Game::factory()->count(6)->create();
        Event::fake([ClanToast::class, ClanUpdated::class]);

        app(ClanWarService::class)->startAttack($attacker, $clanB, $game);
        $this->playClanRun($attacker, $game, $period, 500);
        Event::assertDispatched(ClanUpdated::class, fn (ClanUpdated $e) => $e->broadcastOn()->name === "private-clans.{$clanB->id}"
            && in_array(ClanUpdated::STATUS, $e->broadcastWith()['parts'], true));

        Sanctum::actingAs($defender);
        $attackId = \App\Models\ClanAttack::query()->sole()->id;
        $this->postJson("/api/clan-attacks/{$attackId}/defend")->assertCreated();
        $this->assertSame('repelled', $this->playClanRun($defender, $game, $period, 501)['result']);
        Event::assertDispatched(ClanToast::class, fn (ClanToast $e) => $e->broadcastOn()->name === "private-clans.{$clanB->id}"
            && $e->broadcastWith()['kind'] === ClanToast::DEFENSE_REPELLED
            && $e->broadcastWith()['player']['display_name'] === $defender->display_name
            && $e->broadcastWith()['game']['name'] === $game->name
            && $e->broadcastWith()['score'] === 501);

        $step = app(ClanMissionService::class)->currentMission($clanB)->steps->first();
        app(ClanMissionService::class)->startStep($defender, $step);
        $this->assertSame('completed', $this->playClanRun($defender, $step->game, $period, $step->target_score)['result']);
        Event::assertDispatched(ClanToast::class, fn (ClanToast $e) => $e->broadcastWith()['kind'] === ClanToast::STEP_COMPLETED
            && $e->broadcastWith()['score'] === $step->target_score);
        Event::assertDispatched(ClanUpdated::class, fn (ClanUpdated $e) => in_array(ClanUpdated::MISSIONS, $e->broadcastWith()['parts'], true));
    }

    // the mission over: the members are told the next one is there, it is made when one of them opens the missions
    public function test_a_mission_over_announces_the_next_one(): void
    {
        ClanSettings::fake(['bonus_chance' => 0]);
        $this->period();
        $clan = Clan::factory()->withLeader()->create();
        Game::factory()->count(6)->create();
        $mission = app(ClanMissionService::class)->currentMission($clan);

        Event::fake([ClanToast::class]);
        $this->artisan('kado:clans:expire-missions')->assertSuccessful();
        Event::assertNotDispatched(ClanToast::class);

        $this->travel(25)->hours();
        $this->artisan('kado:clans:expire-missions')->assertSuccessful();
        $this->assertSame(ClanMission::FAILED, $mission->fresh()->status);
        $this->assertSame(0, ClanMission::query()->where('status', ClanMission::ACTIVE)->count());
        Event::assertDispatched(ClanToast::class, fn (ClanToast $e) => $e->broadcastWith()['kind'] === ClanToast::MISSION_AVAILABLE
            && $e->broadcastWith()['clan_id'] === $clan->id);
    }

    public function test_the_forum_of_the_clan_is_followed(): void
    {
        $this->period();
        $leader = User::factory()->create();
        $clan = Clan::factory()->withLeader($leader)->create();
        Event::fake([ClanForumUpdated::class]);

        Sanctum::actingAs($leader);
        $topicId = $this->postJson("/api/clans/{$clan->id}/forum/topics", ['title' => 'Stratégie', 'content' => 'On attaque ce soir'])
            ->assertCreated()->json('data.id');
        $this->postJson("/api/clans/{$clan->id}/forum/topics/{$topicId}/messages", ['content' => 'Go !'])->assertSuccessful();

        Event::assertDispatchedTimes(ClanForumUpdated::class, 2);
        Event::assertDispatched(ClanForumUpdated::class, fn (ClanForumUpdated $e) => $e->broadcastOn()->name === "private-clans.{$clan->id}"
            && $e->broadcastWith() === ['topic_id' => $topicId, 'deleted' => false]);
    }
}
