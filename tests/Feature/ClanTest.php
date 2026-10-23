<?php

namespace Tests\Feature;

use App\Enums\ClanAttackStatus;
use App\Enums\ClanBonusType;
use App\Enums\ClanCombatRole;
use App\Enums\ClanRole;
use App\Exceptions\ClanException;
use App\Filament\Pages\ManageClanSettings;
use App\Models\Clan;
use App\Models\ClanAction;
use App\Models\ClanApplication;
use App\Models\ClanAttack;
use App\Models\ClanBonus;
use App\Models\ClanMemberStat;
use App\Models\ClanMission;
use App\Models\ClanMissionStep;
use App\Models\ClanPeriodScore;
use App\Models\Game;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use App\Models\UserPoint;
use App\Services\ClanMissionService;
use App\Services\ClanPeriodService;
use App\Services\ClanRunService;
use App\Services\ClanService;
use App\Services\ClanWarService;
use App\Settings\ClanSettings;
use App\Settings\SiteSettings;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Laravel\Sanctum\Sanctum;
use Livewire\Livewire;
use Tests\Concerns\EnablesClans;
use Tests\Concerns\PlayableGames;
use Tests\TestCase;

class ClanTest extends TestCase
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

    public function test_a_player_creates_a_clan_and_accepts_an_application(): void
    {
        $this->period();
        $leader = User::factory()->create(['kado_points' => 6000]);
        $player = User::factory()->create(['kado_points' => 1000]);

        Sanctum::actingAs($leader);
        $clanId = $this->postJson('/api/clans', ['name' => 'Boule de neige'])->assertCreated()->json('data.id');
        // ClanSettings::$creation_price
        $this->assertSame(1000, $leader->fresh()->kado_points);
        $this->assertDatabaseHas('user_points', ['user_id' => $leader->id, 'delta' => -5000, 'reason' => 'clan creation', 'source_id' => $clanId]);

        Sanctum::actingAs($player);
        $applicationId = $this->postJson("/api/clans/{$clanId}/applications", ['message' => 'Salut !'])->assertCreated()->json('data.id');
        $this->postJson("/api/clans/{$clanId}/applications")->assertStatus(422)
            ->assertJsonPath('message', 'Vous avez déjà envoyé votre candidature à ce clan.');
        // several clans at once, ClanSettings::$application_price each
        $other = Clan::factory()->withLeader()->create();
        $refusing = Clan::factory()->withLeader()->create();
        $otherId = $this->postJson("/api/clans/{$other->id}/applications")->assertCreated()->json('data.id');
        $refusedId = $this->postJson("/api/clans/{$refusing->id}/applications")->assertCreated()->json('data.id');
        $this->assertSame(700, $player->fresh()->kado_points);

        // refused: paid back
        Sanctum::actingAs($refusing->leader);
        $this->postJson("/api/clan-applications/{$refusedId}/refuse")->assertNoContent();
        $this->postJson("/api/clan-applications/{$refusedId}/refuse")->assertStatus(422);
        $this->assertSame(800, $player->fresh()->kado_points);

        Sanctum::actingAs($leader);
        $this->getJson("/api/clans/{$clanId}/applications")->assertOk()->assertJsonPath('data.0.message', 'Salut !');
        $this->postJson("/api/clan-applications/{$applicationId}/accept")->assertNoContent();

        $this->getJson("/api/clans/{$clanId}/members")->assertOk()->assertJsonCount(2, 'data');
        $this->getJson("/api/clans/{$clanId}")->assertOk()
            ->assertJsonPath('data.members_count', 2)
            ->assertJsonPath('data.viewer.is_leader', true);
        // accepted: the other applications are cancelled and paid back, the accepted one is kept
        $this->assertSame(ClanApplication::CANCELLED, ClanApplication::query()->find($otherId)->status);
        $this->assertSame(900, $player->fresh()->kado_points);
        $this->assertSame(2, UserPoint::query()->where('user_id', $player->id)->where('reason', 'clan application refund')->count());
    }

    public function test_a_clan_and_an_application_need_enough_kado_points(): void
    {
        $this->period();
        $clan = Clan::factory()->withLeader()->create();
        $player = User::factory()->create(['kado_points' => 4999]);
        Sanctum::actingAs($player);

        $this->postJson('/api/clans', ['name' => 'Boule de neige'])->assertStatus(422)
            ->assertJsonPath('message', 'Il vous faut 5.000 points Kado pour créer un clan.');
        $player->update(['kado_points' => 99]);
        $this->postJson("/api/clans/{$clan->id}/applications")->assertStatus(422)
            ->assertJsonPath('message', 'Il vous faut 100 points Kado pour envoyer une candidature.');
        $this->assertSame(0, Clan::query()->where('name', 'Boule de neige')->count());
        $this->assertSame(0, ClanApplication::count());
        $this->assertSame(99, $player->fresh()->kado_points);

        // free when the prices are 0
        ClanSettings::fake(['creation_price' => 0, 'application_price' => 0]);
        $this->postJson("/api/clans/{$clan->id}/applications")->assertCreated();
        $this->assertSame(99, $player->fresh()->kado_points);
    }

    // withdrawn, the clan created or disbanded: the applications waiting are paid back, once
    public function test_the_applications_are_paid_back_when_they_are_closed(): void
    {
        $this->period();
        $player = User::factory()->create(['kado_points' => 5300]);
        [$first, $second, $third] = Clan::factory()->count(3)->withLeader()->create();
        Sanctum::actingAs($player);
        $firstId = $this->postJson("/api/clans/{$first->id}/applications")->assertCreated()->json('data.id');
        $this->postJson("/api/clans/{$second->id}/applications")->assertCreated();
        $this->postJson("/api/clans/{$third->id}/applications")->assertCreated();
        $this->assertSame(5000, $player->fresh()->kado_points);

        $this->deleteJson("/api/clan-applications/{$firstId}")->assertNoContent();
        $this->deleteJson("/api/clan-applications/{$firstId}")->assertNotFound();
        $this->assertSame(5100, $player->fresh()->kado_points);

        Sanctum::actingAs($second->leader);
        $this->deleteJson("/api/clans/{$second->id}")->assertNoContent();
        $this->assertSame(5200, $player->fresh()->kado_points);

        // the last one with the creation of his clan
        Sanctum::actingAs($player);
        $this->postJson('/api/clans', ['name' => 'Boule de neige'])->assertCreated();
        $this->assertSame(300, $player->fresh()->kado_points);
        $this->assertSame(ClanApplication::CANCELLED, ClanApplication::query()->where('clan_id', $third->id)->sole()->status);
        $this->assertSame(3, UserPoint::query()->where('user_id', $player->id)->where('reason', 'clan application refund')->count());
    }

    // only the characters of the letters of the clan pages, at least a letter, unique whatever the case
    public function test_the_name_of_a_clan(): void
    {
        $this->period();
        Clan::factory()->withLeader()->create(['name' => 'Les Pirates']);
        Sanctum::actingAs(User::factory()->create(['kado_points' => 5000]));

        foreach (['Les_Pirates', 'Kado & Co', 'Clan 🦊', '<b>Clan</b>'] as $name) {
            $this->postJson('/api/clans', ['name' => $name])->assertStatus(422)
                ->assertJsonPath('errors.name.0', 'Le nom du clan ne peut contenir que des lettres, des chiffres, des espaces et les signes - \' . ! ?');
        }
        $this->postJson('/api/clans', ['name' => '2010 !'])->assertStatus(422)
            ->assertJsonPath('errors.name.0', 'Le nom du clan doit contenir au moins une lettre.');
        $this->postJson('/api/clans', ['name' => 'les PIRATES'])->assertStatus(422)
            ->assertJsonPath('errors.name.0', 'Ce nom de clan est déjà pris.');
        $this->postJson('/api/clans', ['name' => '   a   '])->assertStatus(422)
            ->assertJsonPath('errors.name.0', 'Le nom du clan doit faire au moins 3 caractères.');

        // the accents and the spaces
        $id = $this->postJson('/api/clans', ['name' => "  L'Équipe   des   Kadoïstes !  "])->assertCreated()->json('data.id');
        $this->assertSame("L'Équipe des Kadoïstes !", Clan::query()->find($id)->name);
    }

    public function test_the_leader_must_name_a_new_leader_before_leaving(): void
    {
        $this->period();
        $leader = User::factory()->create();
        $member = User::factory()->create();
        $clan = Clan::factory()->withLeader($leader)->create();
        $clan->members()->create(['user_id' => $member->id]);

        Sanctum::actingAs($leader);
        $this->postJson('/api/clans/leave')->assertStatus(422);
        $this->postJson("/api/clans/{$clan->id}/members/{$member->etwin_id}/leader")->assertNoContent();
        $this->postJson('/api/clans/leave')->assertNoContent();
        $this->assertSame($member->id, $clan->fresh()->leader_id);

        // the last member leaving disbands the clan
        Sanctum::actingAs($member);
        $this->postJson('/api/clans/leave')->assertNoContent();
        $this->assertModelMissing($clan);
    }

    public function test_an_attack_not_repelled_in_time_wins_points_and_the_defender_loses_as_many(): void
    {
        $period = $this->period();
        $attacker = User::factory()->create();
        $defender = User::factory()->create();
        $clanA = Clan::factory()->withLeader($attacker)->create();
        $clanB = Clan::factory()->withLeader($defender)->create();
        ClanPeriodScore::query()->create(['clan_id' => $clanB->id, 'period_id' => $period->id, 'war_score' => 3]);
        $game = Game::factory()->create();

        Sanctum::actingAs($attacker);
        $this->postJson("/api/clans/{$clanB->id}/attacks", ['game_id' => $game->id])->assertCreated();
        $result = $this->playClanRun($attacker, $game, $period, 500);
        $this->assertSame('launched', $result['result']);
        $attack = ClanAttack::query()->sole();
        $this->assertSame(ClanAttackStatus::ACTIVE, $attack->status);
        $this->assertSame(500, $attack->score);
        // one attack at a time
        $this->postJson("/api/clans/{$clanB->id}/attacks", ['game_id' => $game->id])->assertStatus(422);

        $this->travel(13)->hours();
        $this->assertSame(1, app(ClanWarService::class)->resolveExpired());

        $attack->refresh();
        $points = app(ClanService::class)->attackPoints(0, 3);
        $this->assertSame(ClanAttackStatus::WON, $attack->status);
        $this->assertSame($points, $attack->points);
        $this->assertSame($points, ClanPeriodScore::query()->where('clan_id', $clanA->id)->value('war_score'));
        // never below zero
        $this->assertSame(max(0, 3 - $points), ClanPeriodScore::query()->where('clan_id', $clanB->id)->value('war_score'));
        $this->assertDatabaseHas('clan_member_stats', ['user_id' => $attacker->id, 'attacks' => 1, 'attacks_won' => 1, 'performance' => $points]);
    }

    public function test_a_better_score_repels_the_attack_but_not_while_the_defender_attacks(): void
    {
        $period = $this->period();
        $attacker = User::factory()->create();
        $defender = User::factory()->create();
        $clanA = Clan::factory()->withLeader($attacker)->create();
        $clanB = Clan::factory()->withLeader($defender)->create();
        $game = Game::factory()->create();
        $warService = app(ClanWarService::class);

        $warService->startAttack($attacker, $clanB, $game);
        $this->playClanRun($attacker, $game, $period, 500);
        $attack = ClanAttack::query()->sole();

        // a defender with an attack in progress can't defend
        $otherGame = Game::factory()->create();
        $warService->startAttack($defender, $clanA, $otherGame);
        $this->playClanRun($defender, $otherGame, $period, 10);
        Sanctum::actingAs($defender);
        $this->postJson("/api/clan-attacks/{$attack->id}/defend")->assertStatus(422)
            ->assertJsonPath('message', 'Vous ne pouvez pas défendre tant que vous avez une attaque en cours.');

        // ... until he cancels it (only its attacker can)
        $ownAttackId = ClanAttack::query()->latest('id')->value('id');
        Sanctum::actingAs($attacker);
        $this->postJson("/api/clan-attacks/{$ownAttackId}/cancel")->assertStatus(422);
        Sanctum::actingAs($defender);
        $this->postJson("/api/clan-attacks/{$ownAttackId}/cancel")->assertNoContent();
        $this->postJson("/api/clan-attacks/{$attack->id}/defend")->assertCreated();
        $this->assertSame('failed', $this->playClanRun($defender, $game, $period, 500)['result']);

        $this->postJson("/api/clan-attacks/{$attack->id}/defend")->assertCreated();
        $this->assertSame('repelled', $this->playClanRun($defender, $game, $period, 501)['result']);
        $this->assertSame(ClanAttackStatus::REPELLED, $attack->fresh()->status);
        $this->assertSame(1, ClanPeriodScore::query()->where('clan_id', $clanB->id)->value('defenses_won'));
        $this->assertDatabaseHas('clan_member_stats', ['user_id' => $defender->id, 'defenses' => 2, 'defenses_won' => 1]);
    }

    // the presentation is written in Markdown: titles, lists, links and images, without the HTML of the players
    public function test_the_presentation_is_shown_from_markdown(): void
    {
        $leader = User::factory()->create();
        $clan = Clan::factory()->withLeader($leader)->create([
            'description' => "# Titre\n## Sous-titre\n### Petit titre\n- un\n- deux\n\n1. premier\n\n[lien](https://google.fr) [piège](javascript:alert(1))\n![image](https://google.fr/test.png)\n<script>alert(1)</script>",
        ]);
        Sanctum::actingAs($leader);

        $html = $this->getJson("/api/clans/{$clan->id}")->assertOk()->json('data.description_html');
        foreach (['<h1>Titre</h1>', '<h2>Sous-titre</h2>', '<h3>Petit titre</h3>', '<li>un</li>', '<ol>', '<img src="https://google.fr/test.png" alt="image" />', '&lt;script&gt;'] as $part) {
            $this->assertStringContainsString($part, $html);
        }
        $this->assertStringContainsString('target="_blank" href="https://google.fr"', $html);
        $this->assertStringNotContainsString('javascript:', $html);
        $this->assertStringNotContainsString('<script>', $html);
    }

    // "Statut" shows the attacks waiting for a defense, "Historique" the finished ones (not the cancelled ones), from the
    // side of the clan
    public function test_the_status_shows_the_running_attacks_and_the_history_the_finished_ones(): void
    {
        $period = $this->period();
        [$attacker1, $attacker2, $attacker3, $attacker4, $defender] = User::factory()->count(5)->create();
        $clanA = Clan::factory()->withLeader($attacker1)->create();
        foreach ([$attacker2, $attacker3, $attacker4] as $member) {
            $clanA->members()->create(['user_id' => $member->id]);
        }
        $clanB = Clan::factory()->withLeader($defender)->create();
        $game = Game::factory()->create();
        $warService = app(ClanWarService::class);

        // won: not repelled in time
        $warService->startAttack($attacker1, $clanB, $game);
        $this->playClanRun($attacker1, $game, $period, 500);
        $this->travel(13)->hours();
        $warService->resolveExpired();
        $won = ClanAttack::query()->sole();
        // repelled
        $warService->startAttack($attacker2, $clanB, $game);
        $this->playClanRun($attacker2, $game, $period, 300);
        $repelled = ClanAttack::query()->latest('id')->first();
        Sanctum::actingAs($defender);
        $this->postJson("/api/clan-attacks/{$repelled->id}/defend")->assertCreated();
        $this->playClanRun($defender, $game, $period, 301);
        // cancelled
        $warService->startAttack($attacker3, $clanB, $game);
        $this->playClanRun($attacker3, $game, $period, 200);
        Sanctum::actingAs($attacker3);
        $this->postJson('/api/clan-attacks/'.ClanAttack::query()->latest('id')->value('id').'/cancel')->assertNoContent();
        // running
        $warService->startAttack($attacker4, $clanB, $game);
        $this->playClanRun($attacker4, $game, $period, 100);
        $running = ClanAttack::query()->latest('id')->first();

        $this->getJson("/api/clans/{$clanA->id}/status")->assertOk()
            ->assertJsonCount(1, 'data.launched')
            ->assertJsonPath('data.launched.0.id', $running->id)
            ->assertJsonCount(0, 'data.received');

        // the attacks of the clan A
        $this->getJson("/api/clans/{$clanA->id}/history")->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.current_page', 1)
            ->assertJsonPath('meta.last_page', 1)
            ->assertJsonPath('data.0.id', $repelled->id)
            ->assertJsonPath('data.0.type', 'attack')
            ->assertJsonPath('data.0.player.etwin_id', $attacker2->etwin_id)
            ->assertJsonPath('data.0.clan.id', $clanB->id)
            ->assertJsonPath('data.0.score', 300)
            ->assertJsonPath('data.0.status_label', 'Repoussée')
            ->assertJsonPath('data.0.other_player.etwin_id', $defender->etwin_id)
            // the score of the defender who repelled it
            ->assertJsonPath('data.0.other_score', 301)
            ->assertJsonPath('data.0.points', 0)
            ->assertJsonPath('data.1.id', $won->id)
            ->assertJsonPath('data.1.score', 500)
            ->assertJsonPath('data.1.status_label', 'Réussie')
            ->assertJsonPath('data.1.other_score', null)
            ->assertJsonPath('data.1.points', $won->points);

        // the defenses of the clan B: its defender and his score, the points he saved
        $this->getJson("/api/clans/{$clanB->id}/history")->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.type', 'defense')
            ->assertJsonPath('data.0.player.etwin_id', $defender->etwin_id)
            ->assertJsonPath('data.0.clan.id', $clanA->id)
            ->assertJsonPath('data.0.score', 301)
            ->assertJsonPath('data.0.other_score', null)
            ->assertJsonPath('data.0.points', $repelled->fresh()->points)
            ->assertJsonPath('data.1.player', null)
            ->assertJsonPath('data.1.score', 500)
            ->assertJsonPath('data.1.status_label', 'Non repoussée')
            ->assertJsonPath('data.1.other_player.etwin_id', $attacker1->etwin_id)
            ->assertJsonPath('data.1.points', -$won->points);
        $this->assertGreaterThan(0, $repelled->fresh()->points);
    }

    // an "Attaquant" has two attacks at a time, a "Défenseur" defends while he attacks, within the seats of the clan
    public function test_the_combat_roles(): void
    {
        $period = $this->period();
        $leader = User::factory()->create();
        $member = User::factory()->create();
        $other = User::factory()->create();
        $clanA = Clan::factory()->withLeader($leader)->create();
        $clanA->members()->create(['user_id' => $member->id]);
        $clanA->members()->create(['user_id' => $other->id]);
        $enemy = User::factory()->create();
        $clanB = Clan::factory()->withLeader($enemy)->create();
        $game = Game::factory()->create();
        $warService = app(ClanWarService::class);

        // 3 members: 1 seat of each
        Sanctum::actingAs($leader);
        $this->putJson("/api/clans/{$clanA->id}/members/{$member->etwin_id}/combat-role", ['combat_role' => 'attacker'])->assertNoContent();
        $this->putJson("/api/clans/{$clanA->id}/members/{$other->etwin_id}/combat-role", ['combat_role' => 'attacker'])->assertStatus(422)
            ->assertJsonPath('message', 'Tous les sièges de Attaquant sont pris (1 pour ce clan).');
        $this->putJson("/api/clans/{$clanA->id}/members/{$other->etwin_id}/combat-role", ['combat_role' => 'defender'])->assertNoContent();
        Sanctum::actingAs($member);
        $this->putJson("/api/clans/{$clanA->id}/members/{$other->etwin_id}/combat-role", ['combat_role' => null])->assertStatus(422);

        // the attacker: two attacks, not a third one
        foreach ([1, 2] as $i) {
            $warService->startAttack($member, $clanB, $game);
            $this->assertSame('launched', $this->playClanRun($member, $game, $period, 100)['result']);
        }
        Sanctum::actingAs($member);
        $this->postJson("/api/clans/{$clanB->id}/attacks", ['game_id' => $game->id])->assertStatus(422);

        // the defender defends while he attacks, the others don't
        $warService->startAttack($enemy, $clanA, $game);
        $this->playClanRun($enemy, $game, $period, 500);
        $attack = ClanAttack::query()->where('attacker_user_id', $enemy->id)->sole();
        $warService->startAttack($other, $clanB, $game);
        $this->playClanRun($other, $game, $period, 100);
        Sanctum::actingAs($member);
        $this->postJson("/api/clan-attacks/{$attack->id}/defend")->assertStatus(422);
        Sanctum::actingAs($other);
        $this->postJson("/api/clan-attacks/{$attack->id}/defend")->assertCreated();
        $this->assertSame('repelled', $this->playClanRun($other, $game, $period, 501)['result']);
    }

    // a seat chosen can't change before the next period
    public function test_the_seats_are_locked_for_the_period(): void
    {
        $period = $this->period();
        $leader = User::factory()->create();
        $member = User::factory()->create();
        $clan = Clan::factory()->withLeader($leader)->create();
        $clan->members()->create(['user_id' => $member->id]);

        Sanctum::actingAs($leader);
        $url = "/api/clans/{$clan->id}/members/{$member->etwin_id}/combat-role";
        $this->putJson($url, ['combat_role' => 'attacker'])->assertNoContent();
        $this->putJson($url, ['combat_role' => 'attacker'])->assertNoContent();
        $this->putJson($url, ['combat_role' => 'defender'])->assertStatus(422)
            ->assertJsonPath('message', 'Le siège de ce joueur a déjà été choisi pendant cette période : il pourra changer à la prochaine période.');
        $this->putJson($url, ['combat_role' => null])->assertStatus(422);
        $this->getJson("/api/clans/{$clan->id}/members")->assertOk()->assertJsonPath('data.1.combat_role_locked', true);

        // the next period
        $this->travelTo($period->end_at->clone()->addMinute());
        Period::factory()->create(['start_at' => now()->startOfDay(), 'end_at' => now()->addDays(13)->endOfDay()]);
        $this->putJson($url, ['combat_role' => 'defender'])->assertNoContent();
    }

    // "Je m'en occupe": any member of the attacked clan reserves the defense or takes the place, only for the information
    public function test_reserving_a_defense_and_a_mission_step(): void
    {
        $period = $this->period();
        $attacker = User::factory()->create();
        $defender = User::factory()->create();
        $other = User::factory()->create();
        Clan::factory()->withLeader($attacker)->create();
        $clanB = Clan::factory()->withLeader($defender)->create();
        $clanB->members()->create(['user_id' => $other->id]);
        Game::factory()->count(6)->create();
        $game = Game::query()->first();

        app(ClanWarService::class)->startAttack($attacker, $clanB, $game);
        $this->playClanRun($attacker, $game, $period, 500);
        $attack = ClanAttack::query()->sole();

        Sanctum::actingAs($attacker);
        $this->postJson("/api/clan-attacks/{$attack->id}/reserve")->assertStatus(422);
        Sanctum::actingAs($defender);
        $this->postJson("/api/clan-attacks/{$attack->id}/reserve")->assertNoContent();
        Sanctum::actingAs($other);
        $this->getJson("/api/clans/{$clanB->id}/status")->assertOk()
            ->assertJsonPath('data.received.0.reserved_by.etwin_id', $defender->etwin_id)
            ->assertJsonPath('data.received.0.reserved_by_me', false);
        // another member takes the place
        $this->postJson("/api/clan-attacks/{$attack->id}/reserve")->assertNoContent();
        $this->assertSame($other->id, $attack->fresh()->reserved_by_user_id);
        // ... and gives it up
        $this->postJson("/api/clan-attacks/{$attack->id}/reserve")->assertNoContent();
        $this->assertNull($attack->fresh()->reserved_by_user_id);
        // the attacker clan does not see the reservations
        $this->postJson("/api/clan-attacks/{$attack->id}/reserve")->assertNoContent();
        Sanctum::actingAs($attacker);
        $this->getJson("/api/clans/{$clanB->id}/status")->assertOk()->assertJsonPath('data.received.0.reserved_by', null);

        // a step of the mission
        $step = app(ClanMissionService::class)->currentMission($clanB)->steps->first();
        Sanctum::actingAs($other);
        $this->postJson("/api/clan-mission-steps/{$step->id}/reserve")->assertNoContent();
        $steps = collect($this->getJson("/api/clans/{$clanB->id}/missions")->assertOk()->json('data.mission.steps'))->keyBy('id');
        $this->assertSame($other->etwin_id, $steps[$step->id]['reserved_by']['etwin_id']);
        $this->assertTrue($steps[$step->id]['reserved_by_me']);
        Sanctum::actingAs($attacker);
        $this->postJson("/api/clan-mission-steps/{$step->id}/reserve")->assertStatus(422);
    }

    // a new run on the game of an attack: its score counts only if it is higher
    public function test_an_attack_is_improved_only_by_a_higher_score(): void
    {
        $period = $this->period();
        $attacker = User::factory()->create();
        Clan::factory()->withLeader($attacker)->create();
        $clanB = Clan::factory()->withLeader()->create();
        $game = Game::factory()->create();

        app(ClanWarService::class)->startAttack($attacker, $clanB, $game);
        $this->playClanRun($attacker, $game, $period, 500);
        $attack = ClanAttack::query()->sole();

        Sanctum::actingAs($attacker);
        $this->getJson("/api/clans/{$clanB->id}/status")->assertOk()->assertJsonPath('data.received.0.can_improve', true);
        $this->postJson("/api/clan-attacks/{$attack->id}/improve")->assertCreated();
        $this->assertSame('not_improved', $this->playClanRun($attacker, $game, $period, 400)['result']);
        $this->assertSame(500, $attack->fresh()->score);

        // 5 hours later: the defenders have 12 hours again
        $this->travel(5)->hours();
        $actionId = $this->postJson("/api/clan-attacks/{$attack->id}/improve")->assertCreated()->json('data.id');
        $this->getJson("/api/clan-actions/{$actionId}")->assertOk()->assertJsonPath('data.is_improvement', true);
        $this->assertSame('improved', $this->playClanRun($attacker, $game, $period, 800)['result']);
        $attack->refresh();
        $this->assertSame(800, $attack->score);
        $this->assertEqualsWithDelta(now()->addHours(12)->timestamp, $attack->expires_at->timestamp, 1);
        // still a single attack
        $this->assertDatabaseCount('clan_attacks', 1);
        $this->assertDatabaseHas('clan_member_stats', ['user_id' => $attacker->id, 'attacks' => 1]);

        // only by its attacker
        Sanctum::actingAs(User::factory()->create());
        $this->postJson("/api/clan-attacks/{$attack->id}/improve")->assertStatus(422);
    }

    // 10 points against a clan with as many points or more, one less by palier of 10 points below, shown before attacking
    public function test_the_points_of_an_attack(): void
    {
        $clanService = app(ClanService::class);
        $this->assertSame(10, $clanService->attackPoints(0, 0));
        $this->assertSame(10, $clanService->attackPoints(0, 100));
        $this->assertSame(10, $clanService->attackPoints(100, 100));
        $this->assertSame(9, $clanService->attackPoints(100, 99));
        $this->assertSame(9, $clanService->attackPoints(100, 90));
        $this->assertSame(8, $clanService->attackPoints(100, 89));
        $this->assertSame(8, $clanService->attackPoints(100, 80));
        $this->assertSame(1, $clanService->attackPoints(100, 0));

        $period = $this->period();
        $attacker = User::factory()->create();
        Clan::factory()->withLeader($attacker)->create();
        $clanB = Clan::factory()->withLeader()->create();
        ClanPeriodScore::query()->create(['clan_id' => $clanB->id, 'period_id' => $period->id, 'war_score' => 30]);

        Sanctum::actingAs($attacker);
        $this->getJson("/api/clans/{$clanB->id}")->assertOk()->assertJsonPath('data.viewer.attack_points', $clanService->attackPoints(0, 30));
    }

    public function test_clans_too_far_apart_are_protected(): void
    {
        $period = $this->period();
        $attacker = User::factory()->create();
        Clan::factory()->withLeader($attacker)->create();
        $strong = Clan::factory()->withLeader()->create();
        ClanPeriodScore::query()->create(['clan_id' => $strong->id, 'period_id' => $period->id, 'war_score' => 500]);
        $game = Game::factory()->create();

        Sanctum::actingAs($attacker);
        $this->postJson("/api/clans/{$strong->id}/attacks", ['game_id' => $game->id])->assertStatus(422);
        $this->getJson("/api/clans/{$strong->id}")->assertOk()
            ->assertJsonPath('data.viewer.attack_blocked', 'Ce clan est protégé de vos attaques : son score est trop éloigné du vôtre.');
    }

    // attacks any time of the period, from its first day; the next period starts again from 0
    public function test_the_attacks_of_the_first_day_and_the_reset_of_the_next_period(): void
    {
        $period = Period::factory()->create(['start_at' => now()->startOfDay(), 'end_at' => now()->addDays(13)->endOfDay()]);
        $attacker = User::factory()->create();
        $clanA = Clan::factory()->withLeader($attacker)->create();
        $clanB = Clan::factory()->withLeader()->create();
        $game = Game::factory()->create();
        $warService = app(ClanWarService::class);
        $clanA->members()->where('user_id', $attacker->id)->update(['combat_role' => ClanCombatRole::ATTACKER]);

        // an attack the first day, won
        $warService->startAttack($attacker, $clanB, $game);
        $this->playClanRun($attacker, $game, $period, 100);
        $this->travel(13)->hours();
        $this->assertSame(1, $warService->resolveExpired());

        // two attacks at the same time (an "Attaquant"), launched a few hours before the end
        $this->travelTo($period->end_at->clone()->subHours(2));
        $warService->startAttack($attacker, $clanB, $game);
        $this->playClanRun($attacker, $game, $period, 100);
        $warService->startAttack($attacker, $clanB, $game);
        $this->assertSame('launched', $this->playClanRun($attacker, $game, $period, 100)['result']);

        // the period ends: the attacks not over are cancelled
        $this->travelTo($period->end_at->clone()->addMinute());
        $nextPeriod = Period::factory()->create(['start_at' => now()->startOfDay(), 'end_at' => now()->addDays(13)->endOfDay()]);
        app(ClanPeriodService::class)->closePeriod($period);
        $this->assertSame(
            [ClanAttackStatus::WON, ClanAttackStatus::CANCELLED, ClanAttackStatus::CANCELLED],
            ClanAttack::query()->orderBy('id')->pluck('status')->all(),
        );
        $this->assertGreaterThan(0, ClanPeriodScore::query()->where('clan_id', $clanA->id)->where('period_id', $period->id)->value('war_score'));

        // day 1 of the next period: the same clans, scores at 0, attacks possible right away
        Sanctum::actingAs($attacker);
        $this->getJson("/api/clans/{$clanA->id}")->assertOk()
            ->assertJsonPath('data.stats.war_score', 0)
            ->assertJsonPath('tournament.period_id', $nextPeriod->id);
        $this->postJson("/api/clans/{$clanB->id}/attacks", ['game_id' => $game->id])->assertCreated();
    }

    public function test_a_mission_completed_gives_its_points_and_opens_the_next_one(): void
    {
        ClanSettings::fake(['bonus_chance' => 1]);
        $period = $this->period();
        $leader = User::factory()->create();
        $member = User::factory()->create();
        $clan = Clan::factory()->withLeader($leader)->create();
        $clan->members()->create(['user_id' => $member->id]);
        Game::factory()->count(8)->create();

        // 5 steps for a clan of 2 members, and the "Jeu cool" and "Jeu caca" options given at the start of the period
        Sanctum::actingAs($member);
        $response = $this->getJson("/api/clans/{$clan->id}/missions")->assertOk()
            ->assertJsonCount(5, 'data.mission.steps')
            ->assertJsonPath('data.mission.reward', 10)
            ->assertJsonCount(2, 'data.bonuses');
        $this->assertEqualsCanonicalizing(['force_game', 'ban_game'], array_column($response->json('data.bonuses'), 'type'));
        $steps = $response->json('data.mission.steps');

        foreach ($steps as $step) {
            $this->postJson("/api/clan-mission-steps/{$step['id']}/play")->assertCreated();
            $game = Game::query()->find($step['game']['id']);
            $this->assertSame('failed', $this->playClanRun($member, $game, $period, $step['target_score'] - 1)['result']);
            $this->postJson("/api/clan-mission-steps/{$step['id']}/play")->assertCreated();
            $this->assertSame('completed', $this->playClanRun($member, $game, $period, $step['target_score'])['result']);
        }

        $mission = ClanMission::query()->where('number', 1)->sole();
        $this->assertSame(ClanMission::COMPLETED, $mission->status);
        $this->assertSame(10, $mission->points);
        $this->assertSame(10, ClanPeriodScore::query()->where('clan_id', $clan->id)->value('mission_score'));
        // an option won with the mission
        $this->assertSame(3, ClanBonus::query()->where('clan_id', $clan->id)->count());
        // 1 point by step in the ranking of the clan
        $this->assertDatabaseHas('clan_member_stats', ['user_id' => $member->id, 'mission_steps' => 5]);
        $this->getJson("/api/clans/{$clan->id}/members")->assertOk()
            ->assertJsonPath('data.0.user.etwin_id', $member->etwin_id)
            ->assertJsonPath('data.0.points', 5);

        // the next mission, and the option won with the previous one
        $response = $this->getJson("/api/clans/{$clan->id}/missions")->assertOk()
            ->assertJsonPath('data.mission.number', 2)
            ->assertJsonPath('data.mission.reward', 10)
            ->assertJsonPath('data.missions.0.number', 1)
            ->assertJsonPath('data.missions.0.bonus.used', false);
        $won = ClanBonus::query()->where('clan_mission_id', $mission->id)->sole();
        $this->assertSame($won->type->value, $response->json('data.missions.0.bonus.type'));
        // the ranking of the missions: the steps done of the mission in progress
        $this->getJson('/api/clans?ranking=missions')->assertOk()
            ->assertJsonPath('data.0.mission', ['number' => 2, 'steps' => 5, 'steps_done' => 0]);
    }

    // two members on the same step: one fails, the other one completes it. The first one plays again: nothing is played
    // for nothing, the page sends them back to the missions
    public function test_a_step_completed_by_another_member_is_not_played_again(): void
    {
        // (more runs begun than the throttle of RunController::begin allows in a minute)
        $this->withoutMiddleware(ThrottleRequests::class);
        $period = $this->period();
        $leader = User::factory()->create(['kado_games' => 5]);
        $member = User::factory()->create();
        $clan = Clan::factory()->withLeader($leader)->create();
        $clan->members()->create(['user_id' => $member->id]);
        Game::factory()->count(8)->create();
        $step = ClanMissionStep::query()->where('clan_mission_id', app(ClanMissionService::class)->currentMission($clan)->id)->firstOrFail();
        $game = Game::query()->findOrFail($step->game_id);

        // the leader fails, and asks to play again (a new clan run on the step, still open)
        Sanctum::actingAs($leader);
        $this->postJson("/api/clan-mission-steps/{$step->id}/play")->assertCreated();
        $this->assertSame('failed', $this->playClanRun($leader, $game, $period, $step->target_score - 1)['result']);
        $failed = ClanAction::query()->where('user_id', $leader->id)->latest('id')->firstOrFail();
        $again = $this->postJson("/api/clan-actions/{$failed->id}/again")->assertOk()->assertJsonPath('closed', null)->json('data.id');
        $this->assertNotNull($again);

        // meanwhile the member completes it
        Sanctum::actingAs($member);
        $this->postJson("/api/clan-mission-steps/{$step->id}/play")->assertCreated();
        $this->assertSame('completed', $this->playClanRun($member, $game, $period, $step->target_score)['result']);

        // the run of the leader is refused (the game shows why), no game of the day used
        Sanctum::actingAs($leader);
        $this->postJson("/api/runs/games/{$game->id}")->assertStatus(422)
            ->assertJsonPath('message', 'Cette étape a déjà été réussie. Retournez sur la page des missions de votre clan.');
        $this->assertSame(5, $leader->fresh()->kado_games);
        $this->assertNotNull(ClanAction::query()->findOrFail($again)->completed_at);
        // and "Rejouer" gives the reason to the page
        $this->postJson("/api/clan-actions/{$failed->id}/again")->assertOk()
            ->assertJsonPath('data', null)
            ->assertJsonPath('closed', 'Cette étape a déjà été réussie.');
        // the next run of the game is a normal one
        $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful();
        $this->assertSame(4, $leader->fresh()->kado_games);
    }

    // a failed step played again from the end screen of the game before the page asked for it ("Rejouer": the end of the
    // run took a while): the new run still counts for the step
    public function test_a_failed_step_played_again_at_once_still_counts(): void
    {
        $this->withoutMiddleware(ThrottleRequests::class);
        $period = $this->period();
        $leader = User::factory()->create(['kado_games' => 5]);
        $clan = Clan::factory()->withLeader($leader)->create();
        Game::factory()->count(8)->create();
        $step = ClanMissionStep::query()->where('clan_mission_id', app(ClanMissionService::class)->currentMission($clan)->id)->firstOrFail();
        $game = Game::query()->findOrFail($step->game_id);
        Sanctum::actingAs($leader);

        $this->postJson("/api/clan-mission-steps/{$step->id}/play")->assertCreated();
        $this->assertSame('failed', $this->playClanRun($leader, $game, $period, $step->target_score - 1)['result']);

        // no "Rejouer" yet: the run begun is bound to the step all the same (free)
        $runId = $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful()
            ->assertJsonPath('data.clan.type', 'mission')
            ->json('data.run_id');
        $this->assertSame(5, $leader->fresh()->kado_games);
        // then "Rejouer" of the page: the clan run already going on, not another one
        $failed = ClanAction::query()->where('user_id', $leader->id)->whereNotNull('completed_at')->sole();
        $this->postJson("/api/clan-actions/{$failed->id}/again")->assertOk()
            ->assertJsonPath('data.id', ClanAction::query()->where('run_id', $runId)->value('id'));
        $this->assertSame(2, ClanAction::query()->where('user_id', $leader->id)->count());
        $run = Run::query()->findOrFail($runId);
        $run->update(['score' => $step->target_score, 'completed_at' => now()]);
        $this->assertSame('completed', app(ClanRunService::class)->handleRunCompleted($run->fresh())['result']);
        $this->assertNotNull($step->fresh()->completed_at);

        // a step completed: the next run is a normal one
        $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful()->assertJsonPath('data.clan', null);
        $this->assertSame(4, $leader->fresh()->kado_games);
    }

    public function test_the_steps_grow_with_the_members_of_the_clan(): void
    {
        $missionService = app(ClanMissionService::class);
        $this->assertSame(5, $missionService->stepsCount(1, 1));
        $this->assertSame(24, $missionService->stepsCount(50, 1));
        $this->assertSame(9, $missionService->stepsCount(11, 1));
        // fewer steps with each mission when the ratio is below 1
        ClanSettings::fake(['mission_steps_ratio' => 0.9]);
        $this->assertLessThan($missionService->stepsCount(50, 1), $missionService->stepsCount(50, 5));

        // one point less every 10 missions
        $this->assertSame(10, $missionService->missionPoints(1));
        $this->assertSame(10, $missionService->missionPoints(9));
        $this->assertSame(9, $missionService->missionPoints(10));
        $this->assertSame(9, $missionService->missionPoints(19));
        $this->assertSame(8, $missionService->missionPoints(20));
        $this->assertSame(1, $missionService->missionPoints(100));
    }

    public function test_a_mission_not_finished_in_time_loses_a_point_by_step_missed_minus_one(): void
    {
        ClanSettings::fake(['bonus_chance' => 0]);
        $period = $this->period();
        $leader = User::factory()->create();
        $clan = Clan::factory()->withLeader($leader)->create();
        Game::factory()->count(10)->create(['stars' => [1000, 2000, 3000]]);
        ClanPeriodScore::query()->create(['clan_id' => $clan->id, 'period_id' => $period->id, 'mission_score' => 20]);
        $missionService = app(ClanMissionService::class);

        // 5 steps, 1 completed: 4 missed, 3 points lost
        $mission = $missionService->currentMission($clan);
        $this->assertCount(5, $mission->steps);
        // the first palier: half the first star
        $this->assertSame([500], $mission->steps->pluck('target_score')->unique()->values()->all());
        $step = $mission->steps->first();
        $missionService->startStep($leader, $step);
        $this->assertSame('completed', $this->playClanRun($leader, $step->game, $period, $step->target_score)['result']);

        $this->travel(25)->hours();
        $next = $missionService->currentMission($clan);
        $this->assertSame(ClanMission::FAILED, $mission->fresh()->status);
        $this->assertSame(-3, $mission->fresh()->points);
        $this->assertSame(17, ClanPeriodScore::query()->where('clan_id', $clan->id)->value('mission_score'));
        // a new mission of the same number
        $this->assertSame(1, $next->number);

        // a single step missed: nothing lost
        $next->steps->slice(1)->each(fn (ClanMissionStep $step) => $step->update(['skipped' => true]));
        $missionService->loseMission($next, ClanMission::FAILED);
        $this->assertSame(17, ClanPeriodScore::query()->where('clan_id', $clan->id)->value('mission_score'));
    }

    // the top difficulty goes up by a quarter of star with each mission from half the first star, then by 10 % of the way to
    // the "Score 1500" of the game beyond the red star; the other steps start from half the first star
    public function test_the_paliers_get_higher_with_the_missions_completed(): void
    {
        ClanSettings::fake(['bonus_chance' => 0, 'mission_stars_per_mission' => 0.25, 'mission_beyond_last_star' => 0.1]);
        $period = $this->period();
        $leader = User::factory()->create();
        $clan = Clan::factory()->withLeader($leader)->create();
        Game::factory()->count(6)->create(['stars' => [1000, 2000, 3000], 'score_rankv1' => 4000]);
        $missionService = app(ClanMissionService::class);

        $hardest = [];
        foreach (range(1, 14) as $number) {
            $mission = $missionService->currentMission($clan);
            $this->assertSame($number, $mission->number);
            $targets = $mission->steps->pluck('target_score');
            $hardest[$number] = $targets->max();
            // the easiest step (a lone player: 5 steps)
            $this->assertSame(500, $targets->min());
            foreach ($mission->steps as $step) {
                $missionService->startStep($leader, $step);
                $this->playClanRun($leader, $step->game, $period, $step->target_score);
            }
        }

        $this->assertSame([1 => 500, 2 => 750, 3 => 1000, 5 => 1500, 7 => 2000, 9 => 2500, 11 => 3000, 12 => 3100, 14 => 3300], array_intersect_key($hardest, array_flip([1, 2, 3, 5, 7, 9, 11, 12, 14])));

        // the star of each step, a "+" above the red one
        $mission = $missionService->currentMission($clan);
        Sanctum::actingAs($leader);
        $steps = collect($this->getJson("/api/clans/{$clan->id}/missions")->assertOk()->json('data.mission.steps'));
        $this->assertSame(['-1' => false], $steps->where('target_score', 500)->mapWithKeys(fn ($step) => [(string) $step['star'] => $step['beyond_last_star']])->all());
        $this->assertSame(3400, $steps->max('target_score'));
        $this->assertSame(['2' => true], $steps->where('target_score', 3400)->mapWithKeys(fn ($step) => [(string) $step['star'] => $step['beyond_last_star']])->all());
        $this->assertSame(15, $mission->number);
    }

    // the runs of the missions don't cost a game, the attacks and the defenses have their own games
    public function test_the_runs_of_the_missions_are_free(): void
    {
        $this->setSettings(SiteSettings::class, ['games_per_day' => 10]);
        $this->period();
        $player = User::factory()->create(['kado_games' => 0, 'clan_attack_games' => 0]);
        $clan = Clan::factory()->withLeader($player)->create();
        $defender = Clan::factory()->withLeader()->create();
        Game::factory()->count(6)->create();
        $mission = app(ClanMissionService::class)->currentMission($clan);
        $step = $mission->steps->first();

        Sanctum::actingAs($player);
        $this->postJson("/api/runs/games/{$step->game_id}")->assertForbidden();
        $this->postJson("/api/clan-mission-steps/{$step->id}/play")->assertCreated();
        $this->postJson("/api/runs/games/{$step->game_id}")->assertSuccessful();
        $this->assertSame(0, $player->fresh()->kado_games);

        // no attack game left
        $this->postJson("/api/clans/{$defender->id}/attacks", ['game_id' => $step->game_id])->assertStatus(422)
            ->assertJsonPath('message', 'Vous n\'avez plus de parties d\'attaque aujourd\'hui. Vous pouvez acheter des parties de clan avec vos points Kado.');
    }

    // more "Jeux cool" than steps: the mission takes some of them at random
    public function test_more_jeux_cool_than_steps(): void
    {
        ClanSettings::fake(['bonus_chance' => 0, 'mission_steps_base' => 2, 'mission_steps_min' => 1, 'mission_steps_ratio' => 1.0]);
        $period = $this->period();
        $leader = User::factory()->create();
        $clan = Clan::factory()->withLeader($leader)->create();
        $games = Game::factory()->count(8)->create();
        $missionService = app(ClanMissionService::class);
        $bonus = fn (ClanBonusType $type) => ClanBonus::query()->create(['clan_id' => $clan->id, 'period_id' => $period->id, 'type' => $type]);

        $missionService->currentMission($clan);
        foreach ($games->take(3) as $game) {
            $missionService->useBonus($leader, $bonus(ClanBonusType::FORCE_GAME), ['game_id' => $game->id]);
        }
        $missionService->useBonus($leader, $bonus(ClanBonusType::NEXT_MISSION));

        $steps = $missionService->currentMission($clan)->steps->pluck('game_id');
        $this->assertCount(2, $steps);
        $this->assertEmpty($steps->diff($games->take(3)->pluck('id')));
    }

    public function test_the_mission_bonuses_of_the_leader_and_his_right_hands(): void
    {
        ClanSettings::fake(['bonus_chance' => 0]);
        $period = $this->period();
        $leader = User::factory()->create();
        $rightHand = User::factory()->create();
        $clan = Clan::factory()->withLeader($leader)->create();
        $clan->members()->create(['user_id' => $rightHand->id, 'role' => ClanRole::RIGHT_HAND]);
        $games = Game::factory()->count(8)->create();
        $missionService = app(ClanMissionService::class);
        $bonus = fn (ClanBonusType $type) => ClanBonus::query()->create(['clan_id' => $clan->id, 'period_id' => $period->id, 'type' => $type]);

        $mission = $missionService->currentMission($clan);
        // "Jeu cool" and "Jeu caca": each one adds its game to its list, the games are in (or never in) the next missions
        $missionService->useBonus($rightHand, $bonus(ClanBonusType::FORCE_GAME), ['game_id' => $games[0]->id]);
        $missionService->useBonus($leader, $bonus(ClanBonusType::FORCE_GAME), ['game_id' => $games[1]->id]);
        $missionService->useBonus($leader, $bonus(ClanBonusType::BAN_GAME), ['game_id' => $games[2]->id]);
        // a game is in one list, once: the option is not used
        $refused = function (ClanBonusType $type, Game $game, string $message) use ($missionService, $leader, $bonus) {
            $option = $bonus($type);
            try {
                $missionService->useBonus($leader, $option, ['game_id' => $game->id]);
                $this->fail($message);
            } catch (ClanException $e) {
                $this->assertSame($message, $e->getMessage());
            }
            $this->assertNull($option->fresh()->used_at);
            $option->delete();
        };
        $refused(ClanBonusType::FORCE_GAME, $games[0], 'Ce jeu est déjà un jeu cool du clan.');
        $refused(ClanBonusType::BAN_GAME, $games[0], 'Ce jeu est un jeu cool du clan : il ne peut pas être aussi un jeu caca.');
        $refused(ClanBonusType::FORCE_GAME, $games[2], 'Ce jeu est un jeu caca du clan : il ne peut pas être aussi un jeu cool.');
        $lists = $missionService->gameLists($clan, $period);
        $this->assertSame([$games[0]->id, $games[1]->id], $lists['forced']->all());
        $this->assertSame([$games[2]->id], $lists['banned']->all());
        Sanctum::actingAs($leader);
        $this->getJson("/api/clans/{$clan->id}/missions")->assertOk()
            ->assertJsonPath('data.forced_games.1.name', $games[1]->name)
            ->assertJsonPath('data.banned_games.0.id', $games[2]->id);
        // "Plus de temps"
        $expiresAt = $mission->expires_at;
        $missionService->useBonus($leader, $bonus(ClanBonusType::MORE_TIME));
        $this->assertTrue($expiresAt->clone()->addHours(6)->eq($mission->fresh()->expires_at));
        // "Mission suivante": a new mission of the same number, without losing points
        $missionService->useBonus($leader, $bonus(ClanBonusType::NEXT_MISSION));
        $this->assertSame(ClanMission::SKIPPED, $mission->fresh()->status);
        $this->assertSame(0, $mission->fresh()->points);

        $next = $missionService->currentMission($clan);
        $this->assertSame(1, $next->number);
        $nextGames = $next->steps->pluck('game_id');
        $this->assertTrue($nextGames->contains($games[0]->id) && $nextGames->contains($games[1]->id));
        $this->assertFalse($nextGames->contains($games[2]->id));

        // "Passe étape" on every step completes the mission
        foreach ($next->steps as $step) {
            $missionService->useBonus($leader, $bonus(ClanBonusType::SKIP_STEP), ['step_id' => $step->id]);
        }
        $this->assertSame(ClanMission::COMPLETED, $next->fresh()->status);
        $this->assertSame(10, ClanPeriodScore::query()->where('clan_id', $clan->id)->value('mission_score'));

        $member = User::factory()->create();
        $clan->members()->create(['user_id' => $member->id]);
        $this->expectExceptionMessage('Seuls le chef de clan et ses bras droits peuvent faire ça.');
        $missionService->useBonus($member, $bonus(ClanBonusType::MORE_TIME));
    }

    public function test_the_status_of_the_members(): void
    {
        $this->period();
        $leader = User::factory()->create();
        $rightHand = User::factory()->create();
        $member = User::factory()->create();
        $other = User::factory()->create();
        $clan = Clan::factory()->withLeader($leader)->create();
        $clan->members()->create(['user_id' => $rightHand->id, 'role' => ClanRole::RIGHT_HAND]);
        $clan->members()->create(['user_id' => $member->id]);
        $status = fn (User $user) => "/api/clans/{$clan->id}/members/{$user->etwin_id}/status";

        // his own status
        Sanctum::actingAs($member);
        $this->putJson($status($member), ['status' => '  dispo le soir '])->assertNoContent();
        $this->assertDatabaseHas('clan_members', ['user_id' => $member->id, 'status' => 'dispo le soir']);
        $this->putJson($status($leader), ['status' => 'en vacances'])->assertStatus(422);
        $this->putJson($status($member), ['status' => str_repeat('a', 61)])->assertStatus(422);
        $members = collect($this->getJson("/api/clans/{$clan->id}/members")->assertOk()->json('data'))->keyBy('user.etwin_id');
        $this->assertSame('dispo le soir', $members[$member->etwin_id]['status']);
        $this->assertTrue($members[$member->etwin_id]['can_edit_status']);
        $this->assertFalse($members[$leader->etwin_id]['can_edit_status']);

        // anyone's for the right hands and the leader
        Sanctum::actingAs($rightHand);
        $this->putJson($status($leader), ['status' => 'en vacances'])->assertNoContent();
        $this->putJson($status($member), ['status' => null])->assertNoContent();
        $this->assertDatabaseHas('clan_members', ['user_id' => $member->id, 'status' => null]);
        $this->assertTrue(collect($this->getJson("/api/clans/{$clan->id}/members")->json('data'))->every('can_edit_status'));

        // the statuses are seen by the clan only
        Sanctum::actingAs($other);
        $this->getJson("/api/clans/{$clan->id}/members")->assertOk()->assertJsonMissingPath('data.0.status');
        $this->putJson($status($member), ['status' => 'coucou'])->assertStatus(422);
    }

    // bought by packs with Kado points, given to the clan, distributed by the leader and the right hands
    public function test_the_paid_clan_games(): void
    {
        $this->period();
        $leader = User::factory()->create(['kado_points' => 1000, 'kado_games' => 5]);
        $member = User::factory()->create(['kado_points' => 0]);
        $clan = Clan::factory()->withLeader($leader)->create();
        $clan->members()->create(['user_id' => $member->id]);

        Sanctum::actingAs($leader);
        $this->getJson('/api/clan-games')->assertOk()
            ->assertJsonPath('data.packs.3', ['count' => 50, 'price' => 1750, 'unit_price' => 35])
            ->assertJsonPath('data.clan.can_distribute', true);
        $this->postJson('/api/clan-games/buy', ['count' => 10])->assertNoContent();
        $this->postJson('/api/clan-games/buy', ['count' => 3])->assertStatus(422);
        $this->postJson('/api/clan-games/buy', ['count' => 50])->assertStatus(422)
            ->assertJsonPath('message', 'Vous n\'avez pas assez de points Kado pour acheter ces parties.');
        $leader->refresh();
        $this->assertSame(600, $leader->kado_points);
        $this->assertSame(10, $leader->clan_games);
        $this->assertDatabaseHas('user_points', ['user_id' => $leader->id, 'delta' => -400, 'reason' => 'clan games purchase']);

        // only the paid games can be given, not the games of the day
        $this->postJson("/api/clans/{$clan->id}/games/donate", ['count' => 11])->assertStatus(422);
        $this->postJson("/api/clans/{$clan->id}/games/donate", ['count' => 4])->assertNoContent();
        $this->assertSame(6, $leader->fresh()->clan_games);
        $this->assertSame(4, $clan->fresh()->clan_games);

        // distributed by the leader and the right hands only
        Sanctum::actingAs($member);
        $this->postJson("/api/clans/{$clan->id}/members/{$member->etwin_id}/games", ['count' => 1])->assertStatus(422);
        Sanctum::actingAs($leader);
        $this->postJson("/api/clans/{$clan->id}/members/{$member->etwin_id}/games", ['count' => 5])->assertStatus(422);
        $this->postJson("/api/clans/{$clan->id}/members/{$member->etwin_id}/games", ['count' => 3])->assertNoContent();
        $this->assertSame(3, $member->fresh()->clan_games);
        $this->assertSame(1, $clan->fresh()->clan_games);
        $this->getJson('/api/clan-games')->assertOk()
            ->assertJsonPath('data.clan.transfers.0.type', 'distribution')
            ->assertJsonPath('data.clan.transfers.1.type', 'donation');
    }

    // attacks and defenses: the attack games of the day first, then the paid clan games, never the games of the normal runs
    public function test_the_attack_games_of_the_day_then_the_paid_clan_games(): void
    {
        // (more runs begun than the throttle of RunController::begin allows in a minute)
        $this->withoutMiddleware(ThrottleRequests::class);
        $this->setSettings(SiteSettings::class, ['games_per_day' => 10]);
        $this->period();
        $player = User::factory()->create(['kado_games' => 3, 'clan_attack_games' => 1, 'clan_games' => 1]);
        Clan::factory()->withLeader($player)->create();
        $defender = Clan::factory()->withLeader()->create();
        $game = Game::factory()->create();
        $games = fn () => [$player->fresh()->kado_games, $player->fresh()->clan_attack_games, $player->fresh()->clan_games];
        $attackRun = function () use ($defender, $game) {
            ClanAction::query()->delete();
            $this->postJson("/api/clans/{$defender->id}/attacks", ['game_id' => $game->id])->assertCreated();

            return $this->postJson("/api/runs/games/{$game->id}");
        };

        Sanctum::actingAs($player);
        $attackRun()->assertSuccessful();
        $this->assertSame([3, 0, 1], $games());
        $attackRun()->assertSuccessful();
        $this->assertSame([3, 0, 0], $games());
        ClanAction::query()->delete();
        $this->postJson("/api/clans/{$defender->id}/attacks", ['game_id' => $game->id])->assertStatus(422);

        // a normal run uses a game of the day only
        $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful();
        $this->assertSame([2, 0, 0], $games());

        // the attack games are given again every day (App\Settings\ClanSettings)
        $settings = app(ClanSettings::class);
        $settings->attack_games_per_day = 4;
        $settings->save();
        $this->artisan('kado:reset-daily-games')->assertSuccessful();
        $this->assertSame([10, 4, 0], $games());
    }

    // a player accepted in a clan can't leave it nor be excluded during the period he joined it
    public function test_a_new_member_stays_until_the_next_period(): void
    {
        $period = $this->period();
        $leader = User::factory()->create();
        $player = User::factory()->create(['kado_points' => 100]);
        $clan = Clan::factory()->withLeader($leader)->create();

        Sanctum::actingAs($player);
        $applicationId = $this->postJson("/api/clans/{$clan->id}/applications")->assertCreated()->json('data.id');
        Sanctum::actingAs($leader);
        $this->postJson("/api/clan-applications/{$applicationId}/accept")->assertNoContent();
        $this->getJson("/api/clans/{$clan->id}/members")->assertOk()->assertJsonPath('data.1.is_new', true);
        $this->postJson("/api/clans/{$clan->id}/members/{$player->etwin_id}/kick")->assertStatus(422)
            ->assertJsonPath('message', 'Ce joueur a rejoint le clan pendant cette période : il pourra être exclu à partir de la prochaine période.');
        Sanctum::actingAs($player);
        $this->getJson("/api/clans/{$clan->id}")->assertOk()->assertJsonPath('data.viewer.is_new_member', true);
        $this->postJson('/api/clans/leave')->assertStatus(422);

        // the next period
        $this->travelTo($period->end_at->clone()->addMinute());
        Period::factory()->create(['start_at' => now()->startOfDay(), 'end_at' => now()->addDays(13)->endOfDay()]);
        $this->postJson('/api/clans/leave')->assertNoContent();
    }

    // a clan run begun and never ended (the page closed): shown on the page of the clan, cancelled by its player
    public function test_cancelling_a_clan_run_never_ended(): void
    {
        $period = $this->period();
        $attacker = User::factory()->create();
        $clanA = Clan::factory()->withLeader($attacker)->create();
        $clanB = Clan::factory()->withLeader()->create();
        $game = Game::factory()->create();

        // an attack begun, the page closed
        Sanctum::actingAs($attacker);
        $actionId = $this->postJson("/api/clans/{$clanB->id}/attacks", ['game_id' => $game->id])->assertCreated()->json('data.id');
        $runId = $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful()->json('data.run_id');
        $this->getJson("/api/clans/{$clanA->id}")->assertOk()
            ->assertJsonPath('data.viewer.unfinished_actions.0.label', 'Attaque en cours…')
            ->assertJsonPath('data.viewer.unfinished_actions.0.target', $clanB->name)
            ->assertJsonPath('data.viewer.unfinished_actions.0.blocks', true);
        $this->postJson("/api/clans/{$clanB->id}/attacks", ['game_id' => $game->id])->assertStatus(422);

        // only by its player
        Sanctum::actingAs(User::factory()->create());
        $this->postJson("/api/clan-actions/{$actionId}/cancel")->assertStatus(422);

        Sanctum::actingAs($attacker);
        $this->postJson("/api/clan-actions/{$actionId}/cancel")->assertNoContent();
        $this->assertDatabaseHas('clan_actions', ['id' => $actionId, 'result' => 'cancelled']);
        $this->getJson("/api/clans/{$clanA->id}")->assertOk()->assertJsonCount(0, 'data.viewer.unfinished_actions');
        $this->postJson("/api/clans/{$clanB->id}/attacks", ['game_id' => $game->id])->assertCreated();
        $this->postJson("/api/clan-actions/{$actionId}/cancel")->assertStatus(422);

        // the run ends anyway: a normal run, no attack
        $run = Run::query()->find($runId);
        $run->update(['score' => 100, 'completed_at' => now()]);
        $this->assertNull(app(ClanRunService::class)->handleRunCompleted($run->fresh()));
        $this->assertDatabaseCount('clan_attacks', 0);
    }

    // an attack run blocks until it ends or is cancelled, whatever its length; the end of the period cancels it
    public function test_a_long_attack_run_blocks_until_the_end_of_the_period(): void
    {
        $period = $this->period();
        $attacker = User::factory()->create();
        $clanA = Clan::factory()->withLeader($attacker)->create();
        $clanB = Clan::factory()->withLeader()->create();
        $game = Game::factory()->create();

        Sanctum::actingAs($attacker);
        $actionId = $this->postJson("/api/clans/{$clanB->id}/attacks", ['game_id' => $game->id])->assertCreated()->json('data.id');
        $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful();

        // 3 days later: still blocking, still shown
        $this->travel(3)->days();
        $this->postJson("/api/clans/{$clanB->id}/attacks", ['game_id' => $game->id])->assertStatus(422);
        $this->getJson("/api/clans/{$clanA->id}")->assertOk()->assertJsonPath('data.viewer.unfinished_actions.0.blocks', true);

        $this->travelTo($period->end_at->clone()->addMinute());
        Period::factory()->create(['start_at' => now()->startOfDay(), 'end_at' => now()->addDays(13)->endOfDay()]);
        app(ClanPeriodService::class)->closePeriod($period);
        $this->assertDatabaseHas('clan_actions', ['id' => $actionId, 'result' => 'cancelled']);
        $this->postJson("/api/clans/{$clanB->id}/attacks", ['game_id' => $game->id])->assertCreated();
    }

    // "Rejouer" on the page of a clan run: the next run counts for the clan while its target is open
    // the page of a mission step sends its action when a run begins: the step goes on there however long the player stays
    // on the page (ClanWarService::ACTION_TTL_MINUTES only for the runs begun elsewhere)
    public function test_a_mission_step_counts_on_its_page_however_long_it_stays_open(): void
    {
        $this->withoutMiddleware(ThrottleRequests::class);
        $this->period();
        $leader = User::factory()->create(['kado_games' => 5]);
        $other = User::factory()->create();
        $clan = Clan::factory()->withLeader($leader)->create();
        Game::factory()->count(8)->create();
        $steps = app(ClanMissionService::class)->currentMission($clan)->steps;
        [$step, $otherStep] = [$steps[0], $steps[1]];
        Sanctum::actingAs($leader);
        $actionId = $this->postJson("/api/clan-mission-steps/{$step->id}/play")->assertCreated()->json('data.id');

        // 20 minutes on the page: still open, the run begun there is the action of the page
        $this->travel(20)->minutes();
        $this->getJson("/api/clan-actions/{$actionId}")->assertOk()->assertJsonPath('data.is_open', true);
        $runId = $this->postJson("/api/runs/games/{$step->game_id}", ['clan_action' => $actionId])->assertSuccessful()
            ->assertJsonPath('data.clan.type', 'mission')
            ->json('data.run_id');
        $this->assertSame($runId, ClanAction::query()->findOrFail($actionId)->run_id);
        $this->assertSame(5, $leader->fresh()->kado_games);
        $run = Run::query()->findOrFail($runId);
        $run->update(['score' => $step->target_score - 1, 'completed_at' => now()]);
        $this->assertSame('failed', app(ClanRunService::class)->handleRunCompleted($run->fresh())['result']);

        // the game keeps the action it was given: a new one on the same step ("Rejouer" not asked yet), then the one of
        // "Rejouer", even a long time after
        $runId = $this->postJson("/api/runs/games/{$step->game_id}", ['clan_action' => $actionId])->assertSuccessful()
            ->assertJsonPath('data.clan.type', 'mission')
            ->json('data.run_id');
        $second = ClanAction::query()->where('run_id', $runId)->sole();
        $this->assertSame($step->id, $second->clan_mission_step_id);
        Run::query()->findOrFail($runId)->update(['score' => $step->target_score - 1, 'completed_at' => now()]);
        app(ClanRunService::class)->handleRunCompleted(Run::query()->findOrFail($runId));
        $againId = $this->postJson("/api/clan-actions/{$actionId}/again")->assertOk()->json('data.id');
        $this->travel(30)->minutes();
        $runId = $this->postJson("/api/runs/games/{$step->game_id}", ['clan_action' => $actionId])->assertSuccessful()
            ->json('data.run_id');
        $this->assertSame($runId, ClanAction::query()->findOrFail($againId)->run_id);
        Run::query()->findOrFail($runId)->update(['score' => $step->target_score, 'completed_at' => now()]);
        $this->assertSame('completed', app(ClanRunService::class)->handleRunCompleted(Run::query()->findOrFail($runId))['result']);
        $this->assertSame(5, $leader->fresh()->kado_games);

        // the step completed: the page is closed, a run sent with its action is refused
        $this->getJson("/api/clan-actions/{$actionId}")->assertOk()->assertJsonPath('data.is_open', false);
        $this->postJson("/api/runs/games/{$step->game_id}", ['clan_action' => $actionId])->assertStatus(422)
            ->assertJsonPath('message', 'Cette étape a déjà été réussie. Retournez sur la page des missions de votre clan.');

        // an action of another game or of another player: the run of the game is a normal one
        $otherActionId = $this->postJson("/api/clan-mission-steps/{$otherStep->id}/play")->assertCreated()->json('data.id');
        $this->travel(20)->minutes();
        $this->postJson("/api/runs/games/{$step->game_id}", ['clan_action' => $otherActionId])->assertSuccessful()
            ->assertJsonPath('data.clan', null);
        $this->assertNull(ClanAction::query()->findOrFail($otherActionId)->run_id);
        Sanctum::actingAs($other);
        $this->postJson("/api/runs/games/{$otherStep->game_id}", ['clan_action' => $otherActionId])->assertSuccessful()
            ->assertJsonPath('data.clan', null);
    }

    // the same for an attack, its improvements and a defense: not lost after ClanWarService::ACTION_TTL_MINUTES on the
    // page, checked again when the run begins
    public function test_an_attack_and_a_defense_count_on_their_page_however_long_it_stays_open(): void
    {
        $this->withoutMiddleware(ThrottleRequests::class);
        $this->period();
        $attacker = User::factory()->create(['clan_attack_games' => 5]);
        $defender = User::factory()->create(['clan_attack_games' => 5]);
        $clanA = Clan::factory()->withLeader($attacker)->create();
        $clanB = Clan::factory()->withLeader($defender)->create();
        $game = Game::factory()->create();
        $endRun = function (string $runId, int $score): ?array {
            Run::query()->findOrFail($runId)->update(['score' => $score, 'completed_at' => now()]);

            return app(ClanRunService::class)->handleRunCompleted(Run::query()->findOrFail($runId));
        };

        // a new attack, begun 20 minutes after it was asked
        Sanctum::actingAs($attacker);
        $pageId = $this->postJson("/api/clans/{$clanB->id}/attacks", ['game_id' => $game->id])->assertCreated()->json('data.id');
        $this->travel(20)->minutes();
        $this->getJson("/api/clan-actions/{$pageId}")->assertOk()->assertJsonPath('data.is_open', true);
        $runId = $this->postJson("/api/runs/games/{$game->id}", ['clan_action' => $pageId])->assertSuccessful()
            ->assertJsonPath('data.clan.type', 'attack')
            ->json('data.run_id');
        $this->assertSame('launched', $endRun($runId, 500)['result']);
        $attack = ClanAttack::query()->sole();

        // "Rejouer": an improvement, begun 20 minutes later from the page that still sends the first action
        $againId = $this->postJson("/api/clan-actions/{$pageId}/again")->assertOk()->json('data.id');
        $this->travel(20)->minutes();
        $runId = $this->postJson("/api/runs/games/{$game->id}", ['clan_action' => $pageId])->assertSuccessful()
            ->assertJsonPath('data.clan.type', 'attack')
            ->json('data.run_id');
        $this->assertSame($runId, ClanAction::query()->findOrFail($againId)->run_id);
        $this->assertSame('improved', $endRun($runId, 600)['result']);
        $this->assertSame(600, $attack->fresh()->score);
        $this->assertSame(3, $attacker->fresh()->clan_attack_games);
        $againId = $this->postJson("/api/clan-actions/{$againId}/again")->assertOk()->json('data.id');

        // a defense, begun 20 minutes later: it repels the attack
        Sanctum::actingAs($defender);
        $defenseId = $this->postJson("/api/clan-attacks/{$attack->id}/defend")->assertCreated()->json('data.id');
        $this->travel(20)->minutes();
        $runId = $this->postJson("/api/runs/games/{$game->id}", ['clan_action' => $defenseId])->assertSuccessful()
            ->assertJsonPath('data.clan.type', 'defense')
            ->json('data.run_id');
        $this->assertSame('repelled', $endRun($runId, 601)['result']);

        // the attack is over: the improvement still open on the page of the attacker is refused, no game used
        Sanctum::actingAs($attacker);
        $this->getJson("/api/clan-actions/{$againId}")->assertOk()->assertJsonPath('data.is_open', false);
        $this->postJson("/api/runs/games/{$game->id}", ['clan_action' => $pageId])->assertStatus(422)
            ->assertJsonPath('message', 'Cette attaque est terminée. Retournez sur la page de votre clan.');
        $this->assertSame(3, $attacker->fresh()->clan_attack_games);
        $this->assertSame('too_late', ClanAction::query()->findOrFail($againId)->result);
        // then the page plays normal runs
        $this->postJson("/api/runs/games/{$game->id}", ['clan_action' => $pageId])->assertSuccessful()
            ->assertJsonPath('data.clan', null);
    }

    public function test_playing_again_on_the_page_of_a_clan_run(): void
    {
        ClanSettings::fake(['bonus_chance' => 0]);
        $period = $this->period();
        $player = User::factory()->create();
        $clan = Clan::factory()->withLeader($player)->create();
        $clanB = Clan::factory()->withLeader()->create();
        Game::factory()->count(6)->create();
        $step = app(ClanMissionService::class)->currentMission($clan)->steps->first();
        $game = $step->game;

        // a step failed: the next run is the same step
        Sanctum::actingAs($player);
        $actionId = $this->postJson("/api/clan-mission-steps/{$step->id}/play")->assertCreated()->json('data.id');
        $this->playClanRun($player, $game, $period, $step->target_score - 1);
        $actionId = $this->postJson("/api/clan-actions/{$actionId}/again")->assertOk()->json('data.id');
        $this->assertNotNull($actionId);
        $this->assertSame('completed', $this->playClanRun($player, $game, $period, $step->target_score)['result']);
        // completed: the next run is a normal one
        $this->postJson("/api/clan-actions/{$actionId}/again")->assertOk()->assertJsonPath('data', null);

        // an attack launched: the next run improves it
        $actionId = $this->postJson("/api/clans/{$clanB->id}/attacks", ['game_id' => $game->id])->assertCreated()->json('data.id');
        $this->playClanRun($player, $game, $period, 100);
        $actionId = $this->postJson("/api/clan-actions/{$actionId}/again")->assertOk()->json('data.id');
        $this->getJson("/api/clan-actions/{$actionId}")->assertOk()->assertJsonPath('data.is_improvement', true);
        $this->assertSame('improved', $this->playClanRun($player, $game, $period, 200)['result']);
        $this->assertSame(200, ClanAttack::query()->sole()->score);
    }

    public function test_the_admin_sets_the_attack_games_of_the_day(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));

        Livewire::test(ManageClanSettings::class)
            ->assertSet('data.attack_games_per_day', 10)
            ->assertSet('data.bonus_weights.more_time', 30)
            ->set('data.attack_games_per_day', 6)
            ->set('data.bonus_chance', '0.5')
            ->call('save')
            ->assertHasNoErrors();

        $settings = app(ClanSettings::class)->refresh();
        $this->assertSame(6, $settings->attack_games_per_day);
        $this->assertSame(0.5, $settings->bonus_chance);
        // the lists are kept
        $this->assertSame([1 => 50, 5 => 225, 10 => 400, 50 => 1750], $settings->gamePacks());
        $this->assertSame(150000, $settings->rewards('war')[1]);
    }

    // the preview of the steps of the missions follows the form, before saving it
    public function test_the_admin_previews_the_steps_of_the_missions(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));

        Livewire::test(ManageClanSettings::class)
            ->assertSee('pour un clan de 10 membres')
            ->assertSee('Palier le plus haut')
            // a row every 2 missions (a quarter of star by mission), up to the "Score 1500" at the mission 21
            ->assertSee('n° 21')
            ->assertSee('rouge +100 %')
            ->assertDontSee('n° 23')
            ->set('data.mission_stars_per_mission', '0.5')
            ->set('data.mission_beyond_last_star', '0.5')
            ->assertSee('n° 8')
            ->assertSee('1 × grise · 2 × verte · 2 × orange · 3 × rouge +50 %')
            ->assertDontSee('n° 9');
    }

    // the help page shows the rules set in the admin
    public function test_the_rules_of_the_clans_for_the_help(): void
    {
        ClanSettings::fake(['max_members' => 50, 'attack_hours' => 8, 'protection_range' => 50, 'war_rewards' => [['last_rank' => 3, 'points' => 900], ['last_rank' => 1, 'points' => 3000]]]);
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/clans/overview')->assertOk()
            ->assertJsonPath('data.rules.attack_hours', 8)
            ->assertJsonPath('data.rules.attack_points_palier', 5)
            ->assertJsonPath('data.rules.mission_steps_alone', 5)
            ->assertJsonPath('data.rules.mission_steps_full', 24)
            ->assertJsonPath('data.rules.bonus_chance', 7)
            ->assertJsonPath('data.rules.rewards.war', [['from' => 1, 'to' => 1, 'points' => 3000], ['from' => 2, 'to' => 3, 'points' => 900]])
            ->assertJsonPath('data.rules.game_packs.0', ['count' => 1, 'price' => 50]);
    }

    // the leader can do everything, a right hand everything but disband the clan and name a new leader
    public function test_the_roles_of_the_clan(): void
    {
        $this->period();
        $leader = User::factory()->create();
        $rightHand = User::factory()->create();
        $member = User::factory()->create();
        $player = User::factory()->create(['kado_points' => 100]);
        $clan = Clan::factory()->withLeader($leader)->create();
        $clan->members()->create(['user_id' => $rightHand->id]);
        $clan->members()->create(['user_id' => $member->id]);

        Sanctum::actingAs($leader);
        $this->putJson("/api/clans/{$clan->id}/members/{$rightHand->etwin_id}/role", ['role' => 'right_hand'])->assertNoContent();
        $this->putJson("/api/clans/{$clan->id}/members/{$leader->etwin_id}/role", ['role' => 'member'])->assertStatus(422);

        Sanctum::actingAs($player);
        $applicationId = $this->postJson("/api/clans/{$clan->id}/applications")->assertCreated()->json('data.id');

        // the right hand manages the clan
        Sanctum::actingAs($rightHand);
        $this->getJson("/api/clans/{$clan->id}")->assertOk()
            ->assertJsonPath('data.viewer.can_manage', true)
            ->assertJsonPath('data.viewer.role', 'right_hand');
        $this->postJson("/api/clan-applications/{$applicationId}/accept")->assertNoContent();
        $this->putJson("/api/clans/{$clan->id}", ['is_recruiting' => false])->assertNoContent();
        $this->postJson("/api/clans/{$clan->id}/members/{$leader->etwin_id}/kick")->assertStatus(422);
        // ... but does not disband it nor name a new leader
        $this->deleteJson("/api/clans/{$clan->id}")->assertStatus(422);
        $this->postJson("/api/clans/{$clan->id}/members/{$member->etwin_id}/leader")->assertStatus(422);

        // a member does not manage it
        Sanctum::actingAs($member);
        $this->getJson("/api/clans/{$clan->id}")->assertOk()->assertJsonPath('data.viewer.can_manage', false);
        $this->postJson("/api/clans/{$clan->id}/members/{$rightHand->etwin_id}/kick")->assertStatus(422);

        // a new leader: the former one becomes a right hand
        Sanctum::actingAs($leader);
        $this->postJson("/api/clans/{$clan->id}/members/{$member->etwin_id}/leader")->assertNoContent();
        $this->assertSame(ClanRole::RIGHT_HAND, app(ClanService::class)->roleOf($leader, $clan->fresh()));

        Sanctum::actingAs($member);
        $this->deleteJson("/api/clans/{$clan->id}")->assertNoContent();
        $this->assertModelMissing($clan);
        $this->assertDatabaseCount('clan_members', 0);
    }

    public function test_the_end_of_the_period_shares_the_rewards_between_the_members_once(): void
    {
        $period = $this->period();
        $leader = User::factory()->create(['kado_points' => 0]);
        $member = User::factory()->create(['kado_points' => 0]);
        $first = Clan::factory()->withLeader($leader)->create();
        $first->members()->create(['user_id' => $member->id]);
        $second = Clan::factory()->withLeader()->create();
        Clan::factory()->withLeader()->create(); // no score: not ranked
        ClanPeriodScore::query()->create(['clan_id' => $first->id, 'period_id' => $period->id, 'war_score' => 20, 'mission_score' => 5]);
        ClanPeriodScore::query()->create(['clan_id' => $second->id, 'period_id' => $period->id, 'war_score' => 10, 'mission_score' => 50]);

        app(ClanPeriodService::class)->closePeriod($period);
        app(ClanPeriodService::class)->closePeriod($period);

        $score = ClanPeriodScore::query()->where('clan_id', $first->id)->sole();
        $this->assertSame(1, $score->war_rank);
        $this->assertSame(2, $score->mission_rank);
        $expected = intdiv(150000 + 100000, 2);
        $this->assertSame($expected, $leader->fresh()->kado_points);
        $this->assertSame($expected, $member->fresh()->kado_points);
        $this->assertSame(3, ClanMemberStat::query()->whereNotNull('user_point_id')->count());
        $this->assertDatabaseHas('user_points', ['user_id' => $member->id, 'delta' => $expected, 'reason' => 'clan ranking']);
    }

    // choosing a game then leaving the page (or choosing another game) does not count as an attack
    public function test_an_attack_asked_but_not_played_does_not_block_the_next_one(): void
    {
        $period = $this->period();
        $attacker = User::factory()->create();
        Clan::factory()->withLeader($attacker)->create();
        $defender = Clan::factory()->withLeader()->create();
        [$interwheel, $kanji] = Game::factory()->count(2)->create();

        Sanctum::actingAs($attacker);
        $this->postJson("/api/clans/{$defender->id}/attacks", ['game_id' => $interwheel->id])->assertCreated();
        $actionId = $this->postJson("/api/clans/{$defender->id}/attacks", ['game_id' => $kanji->id])->assertCreated()->json('data.id');
        $this->assertDatabaseCount('clan_actions', 1);

        // once the run of the attack is begun, it counts
        $this->postJson("/api/runs/games/{$kanji->id}")->assertSuccessful();
        $this->postJson("/api/clans/{$defender->id}/attacks", ['game_id' => $interwheel->id])->assertStatus(422);
        $this->assertDatabaseHas('clan_actions', ['id' => $actionId]);
    }

    public function test_the_next_run_begun_on_the_game_is_bound_to_the_clan_action(): void
    {
        $this->period();
        $attacker = User::factory()->create();
        Clan::factory()->withLeader($attacker)->create();
        $defender = Clan::factory()->withLeader()->create();
        $game = Game::factory()->create();

        Sanctum::actingAs($attacker);
        $actionId = $this->postJson("/api/clans/{$defender->id}/attacks", ['game_id' => $game->id])->assertCreated()->json('data.id');
        $this->getJson("/api/clan-actions/{$actionId}")->assertOk()->assertJsonPath('data.is_open', true);

        $runId = $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful()->json('data.run_id');

        $this->assertDatabaseHas('clan_actions', ['id' => $actionId, 'run_id' => $runId]);
        $this->getJson("/api/clan-actions/{$actionId}")->assertOk()->assertJsonPath('data.is_open', false);
        // the next one is a normal run
        $otherRunId = $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful()->json('data.run_id');
        $this->assertDatabaseMissing('clan_actions', ['run_id' => $otherRunId]);
    }

    // the goal of the clan run in the bottom bar of the game, instead of the contract: the score of the attack to improve (0
    // for a new one), the score to reach for a defense or a mission step, and the clan games left
    public function test_the_goal_of_a_clan_run_is_given_when_it_begins(): void
    {
        // (more runs begun than the throttle of RunController::begin allows in a minute)
        $this->withoutMiddleware(ThrottleRequests::class);
        $this->setSettings(SiteSettings::class, ['games_per_day' => 10]);
        $period = $this->period();
        $attacker = User::factory()->create(['clan_attack_games' => 2, 'clan_games' => 3]);
        $defender = User::factory()->create();
        $clanA = Clan::factory()->withLeader($attacker)->create();
        $clanB = Clan::factory()->withLeader($defender)->create();
        $game = Game::factory()->create();
        Sanctum::actingAs($attacker);

        // a normal run
        $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful()->assertJsonPath('data.clan', null);

        $this->postJson("/api/clans/{$clanB->id}/attacks", ['game_id' => $game->id])->assertCreated();
        $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful()
            ->assertJsonPath('data.clan', ['type' => 'attack', 'score' => 0, 'attack_games' => 1, 'clan_games' => 3]);
        ClanAction::query()->delete();
        app(ClanWarService::class)->startAttack($attacker, $clanB, $game);
        $this->playClanRun($attacker, $game, $period, 500);
        $attack = ClanAttack::query()->sole();

        $this->postJson("/api/clan-attacks/{$attack->id}/improve")->assertCreated();
        $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful()
            ->assertJsonPath('data.clan', ['type' => 'attack', 'score' => 500, 'attack_games' => 0, 'clan_games' => 3]);

        Sanctum::actingAs($defender);
        $this->postJson("/api/clan-attacks/{$attack->id}/defend")->assertCreated();
        $this->postJson("/api/runs/games/{$game->id}")->assertSuccessful()->assertJsonPath('data.clan.type', 'defense')
            ->assertJsonPath('data.clan.score', 501);

        Game::factory()->count(6)->create();
        $step = app(ClanMissionService::class)->currentMission($clanA)->steps->first();
        Sanctum::actingAs($attacker);
        $this->postJson("/api/clan-mission-steps/{$step->id}/play")->assertCreated();
        $this->postJson("/api/runs/games/{$step->game_id}")->assertSuccessful()->assertJsonPath('data.clan.type', 'mission')
            ->assertJsonPath('data.clan.score', $step->target_score);
    }

    // no clan game left when the run begins (the last one used by another tab...): refused with a message shown in the game
    public function test_a_clan_run_without_clan_games_is_refused_when_it_begins(): void
    {
        $this->period();
        $attacker = User::factory()->create(['clan_attack_games' => 1, 'clan_games' => 0]);
        Clan::factory()->withLeader($attacker)->create();
        $defender = Clan::factory()->withLeader()->create();
        $game = Game::factory()->create();
        Sanctum::actingAs($attacker);

        $actionId = $this->postJson("/api/clans/{$defender->id}/attacks", ['game_id' => $game->id])->assertCreated()->json('data.id');
        $attacker->update(['clan_attack_games' => 0]);

        $this->postJson("/api/runs/games/{$game->id}")->assertForbidden()
            ->assertJsonPath('message', 'Vous n\'avez plus de parties de clan. Vous pouvez en acheter avec vos points Kado.');
        $this->assertSame(0, $game->runs()->count());
        $this->assertDatabaseHas('clan_actions', ['id' => $actionId, 'run_id' => null]);
    }

    // the missions of another clan can be seen, without the reservations of its steps nor its options, and looking at them
    // does not start its next mission
    public function test_the_missions_of_another_clan(): void
    {
        $period = $this->period();
        $leader = User::factory()->create();
        $visitor = User::factory()->create();
        $clan = Clan::factory()->withLeader($leader)->create();
        $idle = Clan::factory()->withLeader()->create();
        Clan::factory()->withLeader($visitor)->create();
        Game::factory()->count(6)->create();
        $step = app(ClanMissionService::class)->currentMission($clan)->steps->first();
        ClanBonus::query()->create(['clan_id' => $clan->id, 'period_id' => $period->id, 'type' => ClanBonusType::SKIP_STEP]);
        Sanctum::actingAs($leader);
        $this->postJson("/api/clan-mission-steps/{$step->id}/reserve")->assertNoContent();
        $this->getJson("/api/clans/{$clan->id}/missions")->assertOk()
            ->assertJsonPath('data.mission.steps.0.reserved_by.etwin_id', $leader->etwin_id)
            // (with the "Jeu cool" and the "Jeu caca" of the start of the period)
            ->assertJsonCount(3, 'data.bonuses');

        Sanctum::actingAs($visitor);
        $this->getJson("/api/clans/{$clan->id}/missions")->assertOk()
            ->assertJsonPath('data.mission.steps.0.target_score', $step->target_score)
            ->assertJsonPath('data.mission.steps.0.reserved_by', null)
            ->assertJsonPath('data.mission.steps.0.reserved_by_me', false)
            ->assertJsonPath('data.bonuses', [])
            ->assertJsonPath('data.banned_games', []);
        $this->postJson("/api/clan-mission-steps/{$step->id}/play")->assertStatus(422);

        $this->getJson("/api/clans/{$idle->id}/missions")->assertOk()->assertJsonPath('data.mission', null);
        $this->assertDatabaseMissing('clan_missions', ['clan_id' => $idle->id]);
    }

    // the leader and the right hands declare the war to 3 clans at most: shown in the "Statut" of both clans
    public function test_the_wars_declared_by_a_clan(): void
    {
        $this->period();
        $leader = User::factory()->create();
        $rightHand = User::factory()->create();
        $member = User::factory()->create();
        $clan = Clan::factory()->withLeader($leader)->create(['name' => 'Les Rouges']);
        $clan->members()->create(['user_id' => $rightHand->id, 'role' => ClanRole::RIGHT_HAND]);
        $clan->members()->create(['user_id' => $member->id]);
        $targets = Clan::factory()->count(4)->withLeader()->create();

        Sanctum::actingAs($member);
        $this->getJson("/api/clans/{$targets[0]->id}")->assertOk()->assertJsonPath('data.viewer.can_declare_war', false);
        $this->postJson("/api/clans/{$targets[0]->id}/war")->assertStatus(422)
            ->assertJsonPath('message', 'Seuls le chef de clan et ses bras droits peuvent faire ça.');

        Sanctum::actingAs($leader);
        $this->getJson("/api/clans/{$targets[0]->id}")->assertOk()
            ->assertJsonPath('data.viewer.can_declare_war', true)
            ->assertJsonPath('data.viewer.at_war', false);
        $this->getJson("/api/clans/{$clan->id}")->assertOk()->assertJsonPath('data.viewer.can_declare_war', false);
        $this->postJson("/api/clans/{$clan->id}/war")->assertStatus(422);
        $this->postJson("/api/clans/{$targets[0]->id}/war")->assertNoContent();
        $this->postJson("/api/clans/{$targets[0]->id}/war")->assertNoContent();
        $this->getJson("/api/clans/{$targets[0]->id}")->assertOk()->assertJsonPath('data.viewer.at_war', true);
        Sanctum::actingAs($rightHand);
        $this->postJson("/api/clans/{$targets[1]->id}/war")->assertNoContent();
        $this->postJson("/api/clans/{$targets[2]->id}/war")->assertNoContent();
        $this->postJson("/api/clans/{$targets[3]->id}/war")->assertStatus(422)
            ->assertJsonPath('message', 'Votre clan est déjà en guerre contre 3 clans : faites la paix avec l\'un d\'eux d\'abord.');
        $this->assertDatabaseCount('clan_wars', 3);

        // in the status of both clans, for anyone
        Sanctum::actingAs(User::factory()->create());
        $this->getJson("/api/clans/{$clan->id}/status")->assertOk()->assertJsonCount(3, 'data.wars');
        $this->getJson("/api/clans/{$targets[0]->id}/status")->assertOk()
            ->assertJsonCount(1, 'data.wars')
            ->assertJsonPath('data.wars.0.clan', ['id' => $clan->id, 'name' => 'Les Rouges'])
            ->assertJsonPath('data.wars.0.target.id', $targets[0]->id);

        // the peace: another war can be declared
        Sanctum::actingAs($leader);
        $this->deleteJson("/api/clans/{$targets[0]->id}/war")->assertNoContent();
        $this->postJson("/api/clans/{$targets[3]->id}/war")->assertNoContent();
        $this->assertDatabaseMissing('clan_wars', ['clan_id' => $clan->id, 'target_clan_id' => $targets[0]->id]);

        // a dissolved clan is no longer at war
        $targets[3]->delete();
        $this->assertDatabaseCount('clan_wars', 2);
    }

    // the wars end with the period; closed again once the next period started, the wars of the new one stay
    public function test_the_wars_end_with_the_period(): void
    {
        $period = $this->period();
        $leader = User::factory()->create();
        Clan::factory()->withLeader($leader)->create();
        [$old, $new] = Clan::factory()->count(2)->withLeader()->create();
        Sanctum::actingAs($leader);
        $this->postJson("/api/clans/{$old->id}/war")->assertNoContent();

        $this->travelTo($period->end_at->copy()->addMinute());
        Period::factory()->create(['start_at' => $period->end_at->copy()->addSecond(), 'end_at' => $period->end_at->copy()->addDays(14)]);
        app(ClanPeriodService::class)->closePeriod($period);
        $this->assertDatabaseCount('clan_wars', 0);

        $this->postJson("/api/clans/{$new->id}/war")->assertNoContent();
        app(ClanPeriodService::class)->closePeriod($period);
        $this->assertDatabaseHas('clan_wars', ['target_clan_id' => $new->id]);
    }

    public function test_the_ranking_and_the_overview(): void
    {
        $period = $this->period();
        $user = User::factory()->create();
        $mine = Clan::factory()->withLeader($user)->create(['name' => 'Les pirates']);
        $best = Clan::factory()->withLeader()->create(['name' => 'Dino RPG']);
        ClanPeriodScore::query()->create(['clan_id' => $best->id, 'period_id' => $period->id, 'war_score' => 42]);
        ClanPeriodScore::query()->create(['clan_id' => $mine->id, 'period_id' => $period->id, 'mission_score' => 7]);

        Sanctum::actingAs($user);
        $this->getJson('/api/clans')->assertOk()
            ->assertJsonPath('data.0.name', 'Dino RPG')
            ->assertJsonPath('data.0.rank', 1)
            ->assertJsonPath('data.1.name', 'Les pirates')
            ->assertJsonPath('tournament.period_id', $period->id);
        $this->getJson('/api/clans?q=pira')->assertOk()->assertJsonPath('data.0.rank', 2);
        $this->getJson('/api/clans/overview')->assertOk()
            ->assertJsonPath('data.clan.id', $mine->id)
            ->assertJsonPath('data.top.0.id', $best->id)
            ->assertJsonPath('data.top_missions.0.id', $mine->id)
            ->assertJsonPath('data.top_missions.0.mission_score', 7);
    }
}
