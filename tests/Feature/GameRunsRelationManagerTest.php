<?php

namespace Tests\Feature;

use App\Filament\Resources\Games\Pages\EditGame;
use App\Filament\Resources\Games\RelationManagers\RunsRelationManager;
use App\Filament\Resources\Users\Pages\EditUser;
use App\Filament\Resources\Users\RelationManagers\RunsRelationManager as UserRunsRelationManager;
use App\Models\Game;
use App\Models\GamePeriodStar;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use App\Models\UserPoint;
use App\Services\ModerationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class GameRunsRelationManagerTest extends TestCase
{
    use RefreshDatabase;

    private function runsOf(Game $game)
    {
        return Livewire::test(RunsRelationManager::class, ['ownerRecord' => $game, 'pageClass' => EditGame::class]);
    }

    public function test_the_admin_deletes_the_replays_of_the_selected_runs(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));
        $game = Game::factory()->create();
        [$a, $b, $kept] = Run::factory()->count(3)->create(['game_id' => $game->id, 'replay' => 'replay-data', 'replay_frames' => 100]);

        $this->runsOf($game)->callTableBulkAction('deleteReplays', [$a, $b]);

        $this->assertNull($a->fresh()->replay);
        $this->assertNull($b->fresh()->replay);
        $this->assertSame('replay-data', $kept->fresh()->replay);
        $this->assertNotNull($a->fresh()->completed_at);
    }

    public function test_the_admin_filters_the_runs_by_completion_date(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));
        $game = Game::factory()->create();
        $old = Run::factory()->create(['game_id' => $game->id, 'completed_at' => '2026-01-10 12:00:00']);
        $inside = Run::factory()->create(['game_id' => $game->id, 'completed_at' => '2026-02-15 23:30:00']);
        $recent = Run::factory()->create(['game_id' => $game->id, 'completed_at' => '2026-03-20 08:00:00']);

        $this->runsOf($game)
            ->filterTable('completed_between', ['from' => '2026-02-01', 'until' => '2026-02-15'])
            ->assertCanSeeTableRecords([$inside])
            ->assertCanNotSeeTableRecords([$old, $recent]);
    }

    public function test_the_columns_can_be_hidden_and_the_seed_is_hidden_by_default(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));
        $table = $this->runsOf(Game::factory()->create())->instance();

        foreach ($table->getTable()->getColumns() as $name => $column) {
            $this->assertTrue($column->isToggleable(), "column {$name}");
        }
        $this->assertTrue($table->isTableColumnToggledHidden('seed'));
        $this->assertFalse($table->isTableColumnToggledHidden('score'));
    }

    /**
     * A player with two runs of a game in a period (35: stars 0 to 2 and a contract of 50 points, 15: star 0) and
     * the first star of another game, rewarded like RunService::confirmRun / rewardStars do.
     */
    private function playerWithStars(): array
    {
        $game = Game::factory()->create(['stars' => [10, 20, 30, 40]]);
        $other = Game::factory()->create();
        $period = Period::factory()->create();
        $player = User::factory()->create(['kado_points' => 100]);
        $best = Run::factory()->for($game)->for($player)->create(['period_id' => $period->id, 'score' => 35, 'contract_score' => 30, 'contract_points' => 50]);
        $second = Run::factory()->for($game)->for($player)->create(['period_id' => $period->id, 'score' => 15]);
        UserPoint::create(['user_id' => $player->id, 'period_id' => $period->id, 'delta' => 50, 'reason' => 'contract completed', 'source_type' => Run::class, 'source_id' => $best->id]);
        foreach ([[$game, 0], [$game, 1], [$game, 2], [$other, 0]] as [$starGame, $star]) {
            GamePeriodStar::create(['game_id' => $starGame->id, 'period_id' => $period->id, 'user_id' => $player->id, 'star' => $star]);
        }
        $player->stars()->create(['period_id' => $period->id, 'green_stars' => 2, 'orange_stars' => 1, 'red_stars' => 1]);

        return [$game, $period, $player, $best, $second];
    }

    private function assertStars(User $player, Game $game, array $gameStars, array $counters): void
    {
        $this->assertSame($gameStars, GamePeriodStar::where('user_id', $player->id)->where('game_id', $game->id)->orderBy('star')->pluck('star')->all());
        $this->assertSame($counters, $player->stars()->sole()->only(['green_stars', 'orange_stars', 'red_stars', 'purple_stars']));
    }

    // a deleted run: its contract points taken back, the stars of the player computed again from the runs left
    // (the other games keep theirs); restored, it gets them back
    public function test_deleting_a_run_takes_back_its_stars_and_contract_points_and_restoring_gives_them_back(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));
        [$game, $period, $player, $best] = $this->playerWithStars();
        cache()->put("promotion_scores_{$game->id}_{$period->id}", 'cached');

        $this->runsOf($game)->callTableAction('delete', $best)->assertHasNoTableActionErrors();

        $this->assertSoftDeleted($best);
        $this->assertSame(50, $player->fresh()->kado_points);
        $this->assertDatabaseHas('user_points', ['user_id' => $player->id, 'delta' => -50, 'reason' => 'deleted run', 'source_id' => $best->id]);
        $this->assertStars($player, $game, [0], ['green_stars' => 2, 'orange_stars' => 0, 'red_stars' => 0, 'purple_stars' => 0]);
        $this->assertFalse(cache()->has("promotion_scores_{$game->id}_{$period->id}"));

        $this->runsOf($game)->filterTable('trashed', true)->callTableAction('restore', $best)->assertHasNoTableActionErrors();

        $this->assertNotSoftDeleted($best);
        $this->assertSame(100, $player->fresh()->kado_points);
        $this->assertDatabaseHas('user_points', ['user_id' => $player->id, 'delta' => 50, 'reason' => 'restored run', 'source_id' => $best->id]);
        $this->assertStars($player, $game, [0, 1, 2], ['green_stars' => 2, 'orange_stars' => 1, 'red_stars' => 1, 'purple_stars' => 0]);

        // deleted again then for good: its points taken back once
        $this->runsOf($game)->callTableAction('delete', $best);
        $this->runsOf($game)->filterTable('trashed', true)->callTableAction('forceDelete', $best)->assertHasNoTableActionErrors();

        $this->assertModelMissing($best);
        $this->assertSame(50, $player->fresh()->kado_points);
        $this->assertStars($player, $game, [0], ['green_stars' => 2, 'orange_stars' => 0, 'red_stars' => 0, 'purple_stars' => 0]);
    }

    // the runs deleted by « Supprimer les scores » keep their points: restored, they get no more
    public function test_restoring_runs_of_deleted_scores_gives_back_the_stars_only(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));
        [$game, , $player, $best, $second] = $this->playerWithStars();
        app(ModerationService::class)->deleteScores($player);

        Livewire::test(UserRunsRelationManager::class, ['ownerRecord' => $player, 'pageClass' => EditUser::class])
            ->filterTable('trashed', false)
            ->callTableBulkAction('restore', [$best, $second])
            ->assertHasNoTableBulkActionErrors();

        $this->assertSame(100, $player->fresh()->kado_points);
        $this->assertStars($player, $game, [0, 1, 2], ['green_stars' => 1, 'orange_stars' => 1, 'red_stars' => 1, 'purple_stars' => 0]);
    }

    public function test_the_admin_deletes_runs_of_a_player_in_bulk(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));
        [$game, , $player, $best, $second] = $this->playerWithStars();

        Livewire::test(UserRunsRelationManager::class, ['ownerRecord' => $player, 'pageClass' => EditUser::class])
            ->callTableBulkAction('delete', [$best, $second])
            ->assertHasNoTableBulkActionErrors();

        $this->assertSame(0, $player->runs()->count());
        $this->assertSame(50, $player->fresh()->kado_points);
        $this->assertStars($player, $game, [], ['green_stars' => 1, 'orange_stars' => 0, 'red_stars' => 0, 'purple_stars' => 0]);
    }
}
