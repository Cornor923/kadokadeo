<?php

namespace Tests\Feature;

use App\Models\Clan;
use App\Models\ClanMemberStat;
use App\Models\Game;
use App\Models\League;
use App\Models\LeaguePromotion;
use App\Models\Period;
use App\Models\PoidsPlumeResult;
use App\Models\User;
use App\Models\UserStar;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

// the tab « dernière période » of the profile (UserController::showPeriod, PeriodSummaryService)
class PeriodSummaryTest extends TestCase
{
    use RefreshDatabase;

    private User $viewer;

    private User $player;

    private Period $older;

    private Period $last;

    private Period $current;

    protected function setUp(): void
    {
        parent::setUp();
        $this->viewer = User::factory()->create();
        $this->player = User::factory()->create();
        $this->older = Period::factory()->create(['start_at' => now()->subDays(30), 'end_at' => now()->subDays(16)]);
        $this->last = Period::factory()->create(['start_at' => now()->subDays(16), 'end_at' => now()->subDays(2)]);
        $this->current = Period::factory()->create(['start_at' => now()->subDays(2), 'end_at' => now()->addDays(11)]);
    }

    public function test_the_last_finished_period_sums_up_the_kado_points_of_its_close(): void
    {
        $game = Game::factory()->create(['name' => 'Promoted Game']);
        $bronze = League::query()->where('level', 1)->firstOrFail();
        $silver = League::query()->where('level', 2)->firstOrFail();
        LeaguePromotion::create([
            'period_id' => $this->last->id,
            'next_period_id' => $this->current->id,
            'game_id' => $game->id,
            'user_id' => $this->player->id,
            'from_league_id' => $bronze->id,
            'to_league_id' => $silver->id,
            'rank_position' => 1,
            'score' => 53800,
            'promotion_slots' => 3,
            'active_players_count' => 40,
            'promotion_reward' => 5000,
        ]);
        PoidsPlumeResult::create([
            'period_id' => $this->last->id,
            'user_id' => $this->player->id,
            'game_ids' => [$game->id],
            'feathers_count' => 2,
            'reward' => 9091,
        ]);
        // two clans in the period: their rewards add up, the clan shown is the one that paid most
        $clan = Clan::factory()->create(['name' => 'Engels']);
        ClanMemberStat::create(['clan_id' => $clan->id, 'user_id' => $this->player->id, 'period_id' => $this->last->id, 'reward' => 11000]);
        ClanMemberStat::create(['clan_id' => Clan::factory()->create()->id, 'user_id' => $this->player->id, 'period_id' => $this->last->id, 'reward' => 538]);
        UserStar::create(['user_id' => $this->player->id, 'period_id' => $this->last->id, 'green_stars' => 23, 'orange_stars' => 7, 'red_stars' => 21]);
        // (the points of another period are not counted)
        PoidsPlumeResult::create(['period_id' => $this->older->id, 'user_id' => $this->player->id, 'game_ids' => [], 'feathers_count' => 1, 'reward' => 100]);

        $this->actingAs($this->viewer, 'sanctum')
            ->getJson("/api/users/{$this->player->etwin_id}/periods")
            ->assertOk()
            ->assertJsonPath('data.period.id', $this->last->id)
            ->assertJsonPath('data.previous_period_id', $this->older->id)
            ->assertJsonPath('data.next_period_id', null)
            ->assertJsonPath('data.clan.name', 'Engels')
            ->assertJsonPath('data.clan.reward', 11538)
            ->assertJsonPath('data.promotions.0.game.name', 'Promoted Game')
            ->assertJsonPath('data.promotions.0.rank_position', 1)
            ->assertJsonPath('data.promotions.0.from_league_id', $bronze->id)
            ->assertJsonPath('data.promotions.0.reward', 5000)
            ->assertJsonPath('data.promotions_reward', 5000)
            ->assertJsonPath('data.feathers.count', 2)
            ->assertJsonPath('data.feathers.reward', 9091)
            ->assertJsonPath('data.stars.green', 23)
            ->assertJsonPath('data.stars.red', 21)
            ->assertJsonPath('data.total', 11538 + 5000 + 9091);
    }

    public function test_an_older_period_and_the_one_after_it(): void
    {
        $this->actingAs($this->viewer, 'sanctum')
            ->getJson("/api/users/{$this->player->etwin_id}/periods/{$this->older->id}")
            ->assertOk()
            ->assertJsonPath('data.period.id', $this->older->id)
            ->assertJsonPath('data.previous_period_id', null)
            ->assertJsonPath('data.next_period_id', $this->last->id)
            ->assertJsonPath('data.clan', null)
            ->assertJsonPath('data.feathers', null)
            ->assertJsonPath('data.total', 0);
    }

    public function test_the_current_period_has_no_summary_yet(): void
    {
        $this->actingAs($this->viewer, 'sanctum')
            ->getJson("/api/users/{$this->player->etwin_id}/periods/{$this->current->id}")
            ->assertNotFound();
    }

    public function test_no_summary_before_the_end_of_the_first_period(): void
    {
        Period::query()->whereKeyNot($this->current->id)->delete();

        $this->actingAs($this->viewer, 'sanctum')
            ->getJson("/api/users/{$this->player->etwin_id}/periods")
            ->assertOk()
            ->assertJsonPath('data', null);
    }

    public function test_it_needs_to_be_logged_in(): void
    {
        $this->getJson("/api/users/{$this->player->etwin_id}/periods")->assertUnauthorized();
    }
}
