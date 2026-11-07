<?php

namespace Tests\Unit;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Rules\Games\Atlanteine\AtlanteineGhostBusterRule;
use App\Achievements\Rules\Games\Kaskade2\Kaskade2SameCellClicksRule;
use App\Achievements\Rules\Games\KSlash\KSlashNoShurikenScoreRule;
use App\Achievements\Rules\Games\PiouPiou\PiouPiouNoBubbleRule;
use App\Achievements\Rules\Games\Starfang\StarfangSameWeaponUpgradesRule;
use App\Achievements\Rules\Games\Synapses\SynapsesChampionRule;
use App\Achievements\Rules\Games\Synapses\SynapsesCrushingVictoryRule;
use App\Models\Game;
use App\Models\Run;
use App\Models\User;
use App\Models\UserAchievementProgress;
use Tests\TestCase;

class BestValueAchievementRulesTest extends TestCase
{
    public function test_same_weapon_upgrades_keeps_the_most_upgrades_of_a_weapon(): void
    {
        $rule = new StarfangSameWeaponUpgradesRule();
        $stats = ['kb' => array_fill(0, 11, 0), 'l' => []];

        $this->assertSame(3, $rule->evaluate($this->event($stats + ['b' => [1, 1, 1, 2, 2, 9, 9, 9, 9]]), $this->progress())->progress);
        $this->assertSame(4, $rule->evaluate($this->event($stats + ['b' => [1, 1]]), $this->progress(4))->progress);
        $this->assertSame(4, $rule->evaluate($this->event($stats + ['b' => []]), $this->progress(4))->progress);
    }

    public function test_ghost_buster_keeps_the_most_ghosts_of_a_finished_level(): void
    {
        $rule = new AtlanteineGhostBusterRule();
        $level = fn (int $ghosts): array => [0, 5, 0, $ghosts, 0, 0, 0, 0];

        $this->assertSame(2, $rule->evaluate($this->event(['s' => [$level(1), $level(2), $level(1)]]), $this->progress())->progress);
        $this->assertSame(2, $rule->evaluate($this->event(['s' => [$level(1)]]), $this->progress(2))->progress);
        $this->assertSame(0, $rule->evaluate($this->event(['s' => []]), $this->progress())->progress);
        // the ghosts of the level the game ended in don't count: « puis le réussir »
        $this->assertSame(1, $rule->evaluate($this->event(['s' => [$level(1), $level(3)]]), $this->progress())->progress);
    }

    public function test_synapses_keep_the_best_level_won_not_the_first(): void
    {
        $level = fn (int $neurons, array $enemies): array => ['to' => 0, 'es' => [$neurons, ...$enemies]];
        $neurons = fn (int $count): array => array_fill(0, $count, 1);
        $stats = [
            'cn' => [$neurons(10), $neurons(10), $neurons(20), $neurons(75), $neurons(30)],
            'ls' => [$level(10, [1]), $level(10, [1]), $level(20, [1, 1, 1, 1]), $level(75, [1, 1, 1, 1]), $level(30, [90, 1, 1, 1])],
        ];

        $this->assertSame(75, (new SynapsesCrushingVictoryRule())->evaluate($this->event($stats), $this->progress())->progress);
        $this->assertSame(75, (new SynapsesChampionRule())->evaluate($this->event($stats), $this->progress())->progress);
        $this->assertSame(80, (new SynapsesChampionRule())->evaluate($this->event($stats), $this->progress(80))->progress);
    }

    public function test_no_bubble_is_the_height_of_the_first_bubble_or_the_whole_climb_without_any(): void
    {
        $rule = new PiouPiouNoBubbleRule();
        $stats = ['b' => [0, 0, 0], 'fb' => [0, 0, 0], 'bp' => [0, 0, 0], 'ch' => 0, 'l' => 40];

        $this->assertSame(40, $rule->evaluate($this->event($stats + ['fbl' => -1]), $this->progress())->progress);
        $this->assertSame(12, $rule->evaluate($this->event($stats + ['fbl' => 12]), $this->progress())->progress);
        $this->assertSame(0, $rule->evaluate($this->event($stats + ['fbl' => 0]), $this->progress())->progress);
    }

    public function test_a_shuriken_thrown_at_score_0_is_a_shuriken(): void
    {
        $rule = new KSlashNoShurikenScoreRule();
        $stats = [
            'k' => [0, 0, 0, 0, 0],
            'sk' => [0, 0, 0, 0, 0],
            'bads' => [0, 0, 0, 0, 0],
            'opt' => array_fill(0, 10, 0),
        ];
        $event = fn (array $stats) => new GameRunCompleted(new User(), new Game(), new Run(['score' => 5000]), $stats);

        $this->assertSame(5000, $rule->evaluate($event($stats + ['fssc' => -1]), $this->progress())->progress);
        $this->assertSame(1200, $rule->evaluate($event($stats + ['fssc' => 1200]), $this->progress())->progress);
        $this->assertSame(0, $rule->evaluate($event($stats + ['fssc' => 0]), $this->progress())->progress);
    }

    public function test_same_cell_clicks_keeps_the_longest_sequence(): void
    {
        $rule = new Kaskade2SameCellClicksRule();
        $clicks = fn (int $sequence): array => array_merge(array_fill(0, $sequence, [1, 1, 0]), array_map(fn (int $i): array => [$i % 8, 2 + intdiv($i, 8), 0], range(1, 20 - $sequence)));
        $stats = ['g' => array_fill(0, 20, 0), 't' => array_fill(0, 20, 0)];

        $this->assertSame(2, $rule->evaluate($this->event($stats + ['d' => $clicks(2)]), $this->progress())->progress);
        $this->assertSame(3, $rule->evaluate($this->event($stats + ['d' => $clicks(3)]), $this->progress())->progress);
        $this->assertSame(3, $rule->evaluate($this->event($stats + ['d' => $clicks(2)]), $this->progress(3))->progress);
    }

    /**
     * @param  array<string, mixed>  $stats
     */
    private function event(array $stats): GameRunCompleted
    {
        return new GameRunCompleted(new User(), new Game(), new Run(), $stats);
    }

    private function progress(int $value = 0): UserAchievementProgress
    {
        return new UserAchievementProgress(['current_value' => $value, 'completed_level' => 0]);
    }
}
