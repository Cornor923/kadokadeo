<?php

namespace Tests\Feature;

use App\Enums\ClanActionType;
use App\Enums\ClanAttackStatus;
use App\Models\Clan;
use App\Models\ClanAction;
use App\Models\ClanAttack;
use App\Models\ClanMemberStat;
use App\Models\ClanMission;
use App\Models\ClanMissionStep;
use App\Models\ClanPeriodScore;
use App\Models\Game;
use App\Models\GamePeriodStar;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use App\Services\ClanMissionService;
use App\Services\ReplayVerifier;
use App\Services\RunService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\EnablesClans;
use Tests\TestCase;

// a run found cheated by the verifier after it counted (RunService::flagAsCheat)
class CheatedRunRevertTest extends TestCase
{
    use EnablesClans, RefreshDatabase;

    private function period(): Period
    {
        return Period::factory()->create(['start_at' => now()->subDay()->startOfDay(), 'end_at' => now()->addDays(12)->endOfDay()]);
    }

    public function test_its_stars_are_those_of_the_best_run_left(): void
    {
        $period = $this->period();
        $user = User::factory()->create();
        $game = Game::factory()->create(['stars' => [10, 20, 30, 40]]);
        $legit = Run::factory()->for($user)->for($game)->for($period)->create(['score' => 15]);
        $cheated = Run::factory()->for($user)->for($game)->for($period)->create(['score' => 45]);
        $runService = app(RunService::class);
        $runService->rewardStars($legit);
        $runService->rewardStars($cheated);
        $this->assertSame(4, GamePeriodStar::where('user_id', $user->id)->count());

        $runService->flagAsCheat($cheated);

        $this->assertSame([0], GamePeriodStar::where('user_id', $user->id)->pluck('star')->all());
        $stars = $user->stars()->where('period_id', $period->id)->sole();
        $this->assertSame([1, 0, 0, 0], [$stars->green_stars, $stars->orange_stars, $stars->red_stars, $stars->purple_stars]);
    }

    public function test_its_attack_is_cancelled_and_its_defense_undone(): void
    {
        $period = $this->period();
        $attacker = User::factory()->create();
        $defender = User::factory()->create();
        $attackers = Clan::factory()->withLeader($attacker)->create();
        $defenders = Clan::factory()->withLeader($defender)->create();
        $game = Game::factory()->create();
        $attackRun = Run::factory()->for($attacker)->for($game)->for($period)->create(['score' => 500]);
        $defenseRun = Run::factory()->for($defender)->for($game)->for($period)->create(['score' => 900]);
        $attack = fn (array $attributes) => ClanAttack::query()->create([
            'period_id' => $period->id, 'game_id' => $game->id, 'attacker_clan_id' => $attackers->id, 'attacker_user_id' => $attacker->id,
            'defender_clan_id' => $defenders->id, 'score' => 500, 'expires_at' => now()->addHours(6), ...$attributes,
        ]);
        $launched = $attack(['run_id' => $attackRun->id, 'status' => ClanAttackStatus::ACTIVE]);
        $repelled = $attack([
            'status' => ClanAttackStatus::REPELLED, 'defender_user_id' => $defender->id, 'defense_run_id' => $defenseRun->id,
            'points' => 3, 'resolved_at' => now(),
        ]);
        ClanPeriodScore::query()->create(['clan_id' => $defenders->id, 'period_id' => $period->id, 'defenses_won' => 1]);
        ClanMemberStat::query()->create(['clan_id' => $defenders->id, 'user_id' => $defender->id, 'period_id' => $period->id, 'defenses_won' => 1, 'performance' => 3]);

        app(RunService::class)->flagAsCheat($attackRun);
        app(RunService::class)->flagAsCheat($defenseRun);

        $this->assertSame(ClanAttackStatus::CANCELLED, $launched->fresh()->status);
        $repelled->refresh();
        $this->assertSame(ClanAttackStatus::ACTIVE, $repelled->status);
        $this->assertNull($repelled->defense_run_id);
        $this->assertSame(0, (int) ClanPeriodScore::query()->where('clan_id', $defenders->id)->value('defenses_won'));
        $stat = ClanMemberStat::query()->where('user_id', $defender->id)->sole();
        $this->assertSame([0, 0], [(int) $stat->defenses_won, (int) $stat->performance]);
    }

    public function test_its_mission_step_is_to_do_again_while_the_mission_goes_on(): void
    {
        $period = $this->period();
        $player = User::factory()->create();
        $clan = Clan::factory()->withLeader($player)->create();
        Game::factory()->count(6)->create();
        $mission = app(ClanMissionService::class)->currentMission($clan);
        $step = ClanMissionStep::query()->where('clan_mission_id', $mission->id)->firstOrFail();
        $run = Run::factory()->for($player)->for($period)->create(['game_id' => $step->game_id, 'score' => 99999]);
        $step->update(['completed_by_user_id' => $player->id, 'run_id' => $run->id, 'score' => 99999, 'completed_at' => now()]);
        ClanMemberStat::query()->create(['clan_id' => $clan->id, 'user_id' => $player->id, 'period_id' => $mission->period_id, 'mission_steps' => 1]);

        app(RunService::class)->flagAsCheat($run);

        $step->refresh();
        $this->assertNull($step->completed_at);
        $this->assertNull($step->run_id);
        $this->assertSame(ClanMission::ACTIVE, $mission->fresh()->status);
        $this->assertSame(0, (int) ClanMemberStat::query()->where('user_id', $player->id)->value('mission_steps'));
    }

    public function test_a_run_of_the_clan_is_verified_even_below_the_best_of_the_player(): void
    {
        config(['kado.replay_verifier.enabled' => true]);
        $period = $this->period();
        $player = User::factory()->create();
        $clan = Clan::factory()->withLeader($player)->create();
        $game = Game::factory()->create();
        $run = Run::factory()->for($player)->for($game)->for($period)->create(['score' => 10]);
        $verifier = app(ReplayVerifier::class);

        $this->assertFalse($verifier->shouldVerify($run, 500));

        ClanAction::query()->create(['user_id' => $player->id, 'clan_id' => $clan->id, 'game_id' => $game->id, 'type' => ClanActionType::MISSION, 'run_id' => $run->id]);
        $this->assertTrue($verifier->shouldVerify($run, 500));
    }
}
