<?php

namespace Tests\Feature;

use App\Models\Run;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class RunWithoutReplayTest extends TestCase
{
    use RefreshDatabase;

    // a column added to the runs must be added to Run::COLUMNS_BUT_REPLAY too
    public function test_the_runs_are_read_with_every_column_but_their_replay(): void
    {
        $columns = array_values(array_diff(Schema::getColumnListing('runs'), ['replay']));
        sort($columns);
        $listed = Run::COLUMNS_BUT_REPLAY;
        sort($listed);
        $this->assertSame($columns, $listed);
    }

    public function test_a_run_read_without_its_replay_knows_it_has_one(): void
    {
        $with = Run::factory()->create(['replay' => 'replay-data']);
        $without = Run::factory()->create(['replay' => null]);

        $runs = Run::query()->withoutReplay()->get()->keyBy('id');

        $this->assertArrayNotHasKey('replay', $runs[$with->id]->getAttributes());
        $this->assertTrue($runs[$with->id]->has_replay);
        $this->assertFalse($runs[$without->id]->has_replay);
    }
}
