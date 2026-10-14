<?php

namespace Tests\Feature;

use App\Filament\Resources\Games\Pages\EditGame;
use App\Filament\Resources\Games\RelationManagers\RunsRelationManager;
use App\Models\Game;
use App\Models\Run;
use App\Models\User;
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
}
