<?php

namespace Tests\Feature;

use App\Enums\RunFlagRule;
use App\Enums\RunFlagStatus;
use App\Models\Game;
use App\Models\Run;
use App\Models\RunFlag;
use App\Models\User;
use App\Services\SuspicionService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SuspicionServiceTest extends TestCase
{
    use RefreshDatabase;

    private function evaluate(Run $run): array
    {
        app(SuspicionService::class)->evaluateFinishedRun($run);

        return RunFlag::where('run_id', $run->id)->pluck('rule')->map(fn (RunFlagRule $r) => $r->value)->sort()->values()->all();
    }

    public function test_the_soft_detections_of_the_game_are_flagged(): void
    {
        $run = Run::factory()->create(['anticheat_flags' => 0x10 | 0x80]);

        $this->assertSame(['client_detection'], $this->evaluate($run));
        $flag = RunFlag::first();
        $this->assertSame(RunFlagStatus::OPEN, $flag->status);
        $this->assertSame('Affichage ajouté par un script, Actions générées par un script', $flag->rule->describe($flag->details));
    }

    public function test_a_replay_longer_than_the_real_time_of_the_run_is_flagged(): void
    {
        // 32 frames by second: 64 s of game in 30 s
        $ahead = Run::factory()->create(['replay_frames' => 64 * 32, 'play_time_seconds' => 30]);
        // late (lag, intro screen): nothing
        $late = Run::factory()->create(['replay_frames' => 20 * 32, 'play_time_seconds' => 60]);

        $this->assertSame(['faster_than_real_time'], $this->evaluate($ahead));
        $this->assertSame([], $this->evaluate($late));
    }

    public function test_only_a_new_record_of_the_game_is_flagged(): void
    {
        config(['kado.suspicion.game_min_runs' => 100]);
        $game = Game::factory()->create();
        Run::factory()->count(100)->for($game)->sequence(fn ($s) => ['score' => $s->index * 10])->create();
        $player = User::factory()->create();
        foreach ([100, 120, 90, 110, 100] as $score) {
            Run::factory()->for($player)->for($game)->create(['score' => $score, 'completed_at' => now()->subHour()]);
        }

        // far above the runs of the player, in the top of the game, but not the record (990)
        $this->assertSame([], $this->evaluate(Run::factory()->for($player)->for($game)->create(['score' => 985])));
        $this->assertSame([], $this->evaluate(Run::factory()->for($player)->for($game)->create(['score' => 990])));
        $record = Run::factory()->for($player)->for($game)->create(['score' => 2000]);
        $this->assertSame(['world_record'], $this->evaluate($record));
        $flag = RunFlag::where('run_id', $record->id)->first();
        $this->assertSame('Ancien record : 990', $flag->rule->describe($flag->details));
    }

    public function test_the_records_of_a_game_with_few_runs_are_not_flagged(): void
    {
        config(['kado.suspicion.game_min_runs' => 100]);
        $game = Game::factory()->create();
        Run::factory()->count(10)->for($game)->create(['score' => 10]);

        $this->assertSame([], $this->evaluate(Run::factory()->for($game)->create(['score' => 2000])));
    }

    public function test_a_flag_evaluated_again_keeps_its_review(): void
    {
        $run = Run::factory()->create(['anticheat_flags' => 0x10]);
        $this->evaluate($run);
        RunFlag::first()->update(['status' => RunFlagStatus::DISMISSED]);

        $this->evaluate($run);

        $this->assertSame(1, RunFlag::count());
        $this->assertSame(RunFlagStatus::DISMISSED, RunFlag::first()->status);
    }

    public function test_a_cheated_run_is_not_evaluated(): void
    {
        $this->assertSame([], $this->evaluate(Run::factory()->create(['anticheat_flags' => 0x10, 'is_cheat' => true])));
    }

    public function test_the_analysis_of_the_game_is_flagged_once_turned_on(): void
    {
        $run = Run::factory()->create();
        $analysis = ['analyzer' => 'binary', 'suspicious' => true, 'metrics' => ['optimalRate' => 0.93], 'reasons' => ['optimal_rate 0.93 >= 0.85 over 42 decisions']];

        config(['kado.replay_analysis.flag' => false]);
        app(SuspicionService::class)->recordAnalysis($run, $analysis);
        $this->assertSame(0, RunFlag::count());

        config(['kado.replay_analysis.flag' => true]);
        app(SuspicionService::class)->recordAnalysis($run, $analysis);
        $flag = RunFlag::first();
        $this->assertSame(RunFlagRule::GAME_ANALYSIS, $flag->rule);
        $this->assertSame('optimal_rate 0.93 >= 0.85 over 42 decisions', $flag->rule->describe($flag->details));
    }
}
