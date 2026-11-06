<?php

namespace Tests\Unit;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Rules\Games\Atlanteine\AtlanteineGhostBusterRule;
use App\Achievements\Rules\Games\Kaskade2\Kaskade2SameCellClicksRule;
use App\Achievements\Rules\Games\Starfang\StarfangSameWeaponUpgradesRule;
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

    public function test_ghost_buster_keeps_the_most_ghosts_of_a_level(): void
    {
        $rule = new AtlanteineGhostBusterRule();
        $level = fn (int $ghosts): array => [0, 5, 0, $ghosts, 0, 0, 0, 0];

        $this->assertSame(2, $rule->evaluate($this->event(['s' => [$level(1), $level(2), $level(1)]]), $this->progress())->progress);
        $this->assertSame(2, $rule->evaluate($this->event(['s' => [$level(1)]]), $this->progress(2))->progress);
        $this->assertSame(0, $rule->evaluate($this->event(['s' => []]), $this->progress())->progress);
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
