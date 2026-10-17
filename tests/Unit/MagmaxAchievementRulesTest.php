<?php

namespace Tests\Unit;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Rules\Games\Magmax\MagmaxBothBonusesRule;
use App\Achievements\Rules\Games\Magmax\MagmaxFlowersOneGameRule;
use App\Achievements\Rules\Games\Magmax\MagmaxGemsCollectedRule;
use App\Achievements\Rules\Games\Magmax\MagmaxKillOrderRule;
use App\Achievements\Rules\Games\Magmax\MagmaxMagmaxRule;
use App\Achievements\Rules\Games\Magmax\MagmaxTurretsKilledRule;
use App\Models\Game;
use App\Models\Run;
use App\Models\User;
use App\Models\UserAchievementProgress;
use Tests\TestCase;

class MagmaxAchievementRulesTest extends TestCase
{
    public function test_stats_are_validated(): void
    {
        $rule = new MagmaxMagmaxRule();

        $this->assertTrue($rule->validate($this->event()));
        $this->assertFalse($rule->validate($this->event(['k' => [1, 2]])));
        $this->assertFalse($rule->validate($this->event(['b' => [1, 0, 0, 0, 0, -1]])));
        $this->assertFalse($rule->validate($this->event(['c' => [0, 0, 0, '1']])));
        $this->assertFalse($rule->validate($this->event(['k' => [11, 4, 3]])));
        $this->assertFalse($rule->validate($this->event(['b' => [10, 5, 2, 1, 1, 0]])));
        $this->assertFalse($rule->validate($this->event(['seq' => 4])));
        $this->assertFalse($rule->validate($this->event(['dual' => 3])));
        $this->assertFalse($rule->validate($this->event(['seq' => null])));
        $this->assertFalse($rule->validate($this->event(['dual' => null])));
    }

    public function test_lifetime_counters_add_the_run_and_are_capped(): void
    {
        $turrets = (new MagmaxTurretsKilledRule())->evaluate($this->event(), $this->progress(5));
        $gems = (new MagmaxGemsCollectedRule())->evaluate($this->event(), $this->progress(5));
        $cappedTurrets = (new MagmaxTurretsKilledRule())->evaluate($this->event([
            'g' => [0, 0, 900],
            'k' => [0, 0, 800],
            'b' => [0, 0, 0, 0, 0, 0],
            'seq' => 0,
            'dual' => 0,
        ]), $this->progress());

        $this->assertSame(8, $turrets->progress);
        $this->assertSame(20, $gems->progress);
        $this->assertSame(500, $cappedTurrets->progress);
    }

    public function test_flowers_keep_the_best_run(): void
    {
        $rule = new MagmaxFlowersOneGameRule();

        $better = $rule->evaluate($this->event(), $this->progress(2));
        $worse = $rule->evaluate($this->event(), $this->progress(9));

        $this->assertSame(4, $better->progress);
        $this->assertFalse($worse->changed);
        $this->assertSame(9, $worse->progress);
    }

    public function test_one_shot_achievements(): void
    {
        $none = $this->event(['c' => [2, 1, 0, 0], 'seq' => 0, 'dual' => 0]);

        $this->assertSame(1, (new MagmaxMagmaxRule())->evaluate($this->event(), $this->progress())->progress);
        $this->assertSame(1, (new MagmaxBothBonusesRule())->evaluate($this->event(), $this->progress())->progress);
        $this->assertSame(1, (new MagmaxKillOrderRule())->evaluate($this->event(), $this->progress())->progress);
        $this->assertFalse((new MagmaxMagmaxRule())->evaluate($none, $this->progress())->changed);
        $this->assertFalse((new MagmaxBothBonusesRule())->evaluate($none, $this->progress())->changed);
        $this->assertFalse((new MagmaxKillOrderRule())->evaluate($none, $this->progress())->changed);
    }

    public function test_invalid_stats_change_nothing(): void
    {
        $result = (new MagmaxTurretsKilledRule())->evaluate($this->event(['seq' => 99]), $this->progress(5));

        $this->assertFalse($result->changed);
        $this->assertSame(5, $result->progress);
    }

    private function event(array $stats = []): GameRunCompleted
    {
        return new GameRunCompleted(
            new User(),
            new Game(['name' => 'Magmax']),
            new Run(),
            array_replace([
                'g' => [10, 5, 4],
                'k' => [10, 4, 3],
                'c' => [3, 2, 1, 1],
                'b' => [10, 4, 1, 1, 1, 0],
                'seq' => 1,
                'dual' => 1,
            ], $stats),
        );
    }

    private function progress(int $value = 0): UserAchievementProgress
    {
        return new UserAchievementProgress([
            'current_value' => $value,
            'state' => [],
        ]);
    }
}
