<?php

namespace Tests\Unit;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Rules\Games\MiniRace\MiniRaceCleanLapsRule;
use App\Achievements\Rules\Games\MiniRace\MiniRaceExplodedRule;
use App\Achievements\Rules\Games\MiniRace\MiniRaceFastLapRule;
use App\Achievements\Rules\Games\MiniRace\MiniRacePerfectFirstLapRule;
use App\Achievements\Rules\Games\MiniRace\MiniRacePinkOvertakesRule;
use App\Achievements\Rules\Games\MiniRace\MiniRaceSlowLapRule;
use App\Models\Game;
use App\Models\Run;
use App\Models\User;
use App\Models\UserAchievementProgress;
use Tests\TestCase;

class MiniRaceAchievementRulesTest extends TestCase
{
    // 3 laps: 9.5 s (fast) with a perfect first lap, 12.2 s off track, 24.3 s; 4 overtakes of the pink car
    private const STATS = [
        '_ot' => [[9, 500, 2], [12, 200], [24, 300]],
        '_lp' => [[0, 1], [1, 0], [0, 0]],
        '_pa' => [2, 1, 4],
        '_x' => 0,
    ];

    public function test_the_fastest_lap_gives_the_level(): void
    {
        $rule = new MiniRaceFastLapRule();

        $this->assertSame(1, $rule->evaluate($this->event([]), $this->progress())->progress);
        $this->assertSame(3, $rule->evaluate($this->event(['_ot' => [[7, 999], [12, 200], [24, 300]]]), $this->progress())->progress);
        $this->assertSame(2, $rule->evaluate($this->event(['_ot' => [[8, 0], [12, 200], [24, 300]]]), $this->progress())->progress);
        $this->assertSame(0, $rule->evaluate($this->event(['_ot' => [[10, 0], [12, 200], [24, 300]]]), $this->progress())->progress);
        $this->assertSame(0, $rule->evaluate($this->event(['_ot' => [], '_lp' => []]), $this->progress())->progress);
        $this->assertSame(2, $rule->evaluate($this->event([]), $this->progress(2))->progress);
    }

    public function test_the_counts_add_up(): void
    {
        $this->assertSame(7, (new MiniRaceCleanLapsRule())->evaluate($this->event([]), $this->progress(5))->progress);
        $this->assertSame(14, (new MiniRacePinkOvertakesRule())->evaluate($this->event([]), $this->progress(10))->progress);
    }

    public function test_the_unique_ones(): void
    {
        $this->assertSame(1, (new MiniRaceSlowLapRule())->evaluate($this->event([]), $this->progress())->progress);
        $this->assertSame(0, (new MiniRaceSlowLapRule())->evaluate($this->event(['_ot' => [[9, 500, 2], [12, 200], [24, 0]]]), $this->progress())->progress);
        $this->assertSame(1, (new MiniRacePerfectFirstLapRule())->evaluate($this->event([]), $this->progress())->progress);
        $this->assertSame(0, (new MiniRacePerfectFirstLapRule())->evaluate($this->event(['_lp' => [[0, 0], [0, 1], [0, 0]]]), $this->progress())->progress);
        $this->assertSame(0, (new MiniRaceExplodedRule())->evaluate($this->event([]), $this->progress())->progress);
        $this->assertSame(1, (new MiniRaceExplodedRule())->evaluate($this->event(['_x' => 1]), $this->progress())->progress);
    }

    public function test_the_stats_must_hold_together(): void
    {
        $rule = new MiniRaceCleanLapsRule();

        $this->assertTrue($rule->validate($this->event([])));
        // the stats of the game before its achievements
        $this->assertFalse($rule->validate($this->event([], ['_ot' => self::STATS['_ot']])));
        $this->assertFalse($rule->validate($this->event(['_lp' => [[0, 1], [1, 0]]])));
        $this->assertFalse($rule->validate($this->event(['_lp' => [[1, 1], [1, 0], [0, 0]]])));
        $this->assertFalse($rule->validate($this->event(['_ot' => [[25, 0], [12, 200], [24, 300]]])));
        $this->assertFalse($rule->validate($this->event(['_ot' => [[9, 1000], [12, 200], [24, 300]]])));
        $this->assertFalse($rule->validate($this->event(['_ot' => array_fill(0, 7, [12, 0]), '_lp' => array_fill(0, 7, [0, 0])])));
        $this->assertFalse($rule->validate($this->event(['_pa' => [2, 1]])));
        $this->assertFalse($rule->validate($this->event(['_x' => 2])));
    }

    private function event(array $changes, ?array $stats = null): GameRunCompleted
    {
        return new GameRunCompleted(new User(), Game::query()->make(['name' => 'Mini-Race']), new Run(['score' => 50000]), array_replace($stats ?? self::STATS, $changes));
    }

    private function progress(int $value = 0): UserAchievementProgress
    {
        return new UserAchievementProgress(['current_value' => $value, 'completed_level' => 0]);
    }
}
