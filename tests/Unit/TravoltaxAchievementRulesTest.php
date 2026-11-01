<?php

namespace Tests\Unit;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Rules\Games\Travoltax\TravoltaxDestroyTenLinesRule;
use App\Models\Game;
use App\Models\Run;
use App\Models\User;
use App\Models\UserAchievementProgress;
use Tests\TestCase;

class TravoltaxAchievementRulesTest extends TestCase
{
    public function test_most_lines_at_once_keeps_the_best_run(): void
    {
        $rule = new TravoltaxDestroyTenLinesRule();

        $better = $rule->evaluate($this->event(['_l' => [1, 4, 2]]), $this->progress(2));
        $worse = $rule->evaluate($this->event(['_l' => [1, 4, 2]]), $this->progress(6));

        $this->assertSame(4, $better->progress);
        $this->assertFalse($worse->changed);
        $this->assertSame(6, $worse->progress);
    }

    public function test_a_run_without_lines_changes_nothing(): void
    {
        $result = (new TravoltaxDestroyTenLinesRule())->evaluate($this->event(['_l' => []]), $this->progress(3));

        $this->assertFalse($result->changed);
        $this->assertSame(3, $result->progress);
    }

    private function event(array $stats = []): GameRunCompleted
    {
        return new GameRunCompleted(
            new User(),
            new Game(['name' => 'Travoltax']),
            new Run(),
            array_replace([
                '_l' => [1, 2],
                '_g' => [0, 0, 0],
                '_o' => [],
                '_c' => [],
                '_t' => 100,
                '_cc' => 0,
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
