<?php

namespace Tests\Unit;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Rules\Games\Bactery\BacteryColoredMarblesRule;
use App\Achievements\Rules\Games\Bactery\BacteryFewBacteriaRule;
use App\Achievements\Rules\Games\Bactery\BacteryHighScoresRule;
use App\Achievements\Rules\Games\Bactery\BacteryPalaceRule;
use App\Achievements\Rules\Games\Bactery\BacteryStonesRule;
use App\Achievements\Rules\Games\Bactery\BacteryTotalStarsRule;
use App\Achievements\Rules\Games\Bactery\BacteryTricolorRule;
use App\Models\Game;
use App\Models\Run;
use App\Models\User;
use App\Models\UserAchievementProgress;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class BacteryAchievementRulesTest extends TestCase
{
    /**
     * @return array<string, array{int, int}>
     */
    public static function bacteria(): array
    {
        return [
            'the fewest' => [4, 3],
            '6' => [6, 3],
            '7' => [7, 2],
            '8' => [8, 2],
            '9' => [9, 1],
            '10' => [10, 1],
            '11' => [11, 0],
            'many' => [40, 0],
        ];
    }

    #[DataProvider('bacteria')]
    public function test_few_bacteria_gives_the_level_of_the_bacteria_left(int $bacteria, int $level): void
    {
        $result = (new BacteryFewBacteriaRule())->evaluate($this->event(['m' => $bacteria, 'k' => 80 - $bacteria]), $this->progress());

        $this->assertSame($level, $result->progress);
    }

    public function test_few_bacteria_keeps_the_best_level(): void
    {
        $result = (new BacteryFewBacteriaRule())->evaluate($this->event(['m' => 10, 'k' => 70]), $this->progress(3));

        $this->assertSame(3, $result->progress);
    }

    public function test_the_stars_add_up(): void
    {
        $result = (new BacteryTotalStarsRule())->evaluate($this->event(['b' => 3, 'k' => 59]), $this->progress(10));

        $this->assertSame(13, $result->progress);
    }

    public function test_the_high_scores_are_counted_from_17000(): void
    {
        $rule = new BacteryHighScoresRule();

        $this->assertSame(3, $rule->evaluate($this->event([], 17000), $this->progress(2))->progress);
        $this->assertFalse($rule->evaluate($this->event([], 16999), $this->progress(2))->changed);
    }

    public function test_palace_needs_the_5_stars_and_no_colored_marble(): void
    {
        $rule = new BacteryPalaceRule();

        $this->assertSame(1, $rule->evaluate($this->event(['b' => 5, 'k' => 0, 'm' => 45, 'w' => 50]), $this->progress())->progress);
        $this->assertSame(0, $rule->evaluate($this->event(['b' => 4, 'k' => 0, 'm' => 46, 'w' => 50]), $this->progress())->progress);
        $this->assertSame(0, $rule->evaluate($this->event(['b' => 5, 'k' => 1, 'm' => 44, 'w' => 50]), $this->progress())->progress);
    }

    public function test_stones_needs_70_stones(): void
    {
        $rule = new BacteryStonesRule();

        $this->assertSame(1, $rule->evaluate($this->event(['w' => 70, 'k' => 10, 'm' => 20, 'b' => 0]), $this->progress())->progress);
        $this->assertSame(0, $rule->evaluate($this->event(['w' => 69, 'k' => 11, 'm' => 20, 'b' => 0]), $this->progress())->progress);
    }

    public function test_tricolor_needs_as_many_of_the_three(): void
    {
        $rule = new BacteryTricolorRule();

        $this->assertSame(1, $rule->evaluate($this->event(['k' => 33, 'm' => 33, 'w' => 33, 'b' => 1]), $this->progress())->progress);
        $this->assertSame(1, $rule->evaluate($this->event(['k' => 32, 'm' => 32, 'w' => 32, 'b' => 4]), $this->progress())->progress);
        $this->assertSame(0, $rule->evaluate($this->event(['k' => 34, 'm' => 33, 'w' => 32, 'b' => 1]), $this->progress())->progress);
    }

    public function test_colored_marbles_needs_85_of_them(): void
    {
        $rule = new BacteryColoredMarblesRule();

        $this->assertSame(1, $rule->evaluate($this->event(['k' => 85, 'm' => 10, 'w' => 3]), $this->progress())->progress);
        $this->assertSame(0, $rule->evaluate($this->event(['k' => 84, 'm' => 11, 'w' => 3]), $this->progress())->progress);
    }

    public function test_the_unique_achievements_stay_obtained(): void
    {
        foreach ([new BacteryPalaceRule(), new BacteryStonesRule(), new BacteryTricolorRule(), new BacteryColoredMarblesRule()] as $rule) {
            $this->assertSame(1, $rule->evaluate($this->event(), $this->progress(1))->progress);
        }
    }

    /**
     * @return array<string, array{array<string, mixed>}>
     */
    public static function invalidStats(): array
    {
        return [
            'nothing' => [['k' => null, 'm' => null, 'w' => null, 'b' => null]],
            'a cell missing' => [['k' => 59]],
            'a cell too many' => [['k' => 61]],
            'too many stars' => [['b' => 6, 'k' => 56]],
            'a negative count' => [['k' => 81, 'm' => -1]],
            'a count not an integer' => [['k' => '60']],
        ];
    }

    /**
     * @param  array<string, mixed>  $stats
     */
    #[DataProvider('invalidStats')]
    public function test_invalid_stats_give_no_progress(array $stats): void
    {
        $event = $this->event($stats, 20000);
        $rules = [new BacteryFewBacteriaRule(), new BacteryTotalStarsRule(), new BacteryHighScoresRule(), new BacteryPalaceRule(), new BacteryStonesRule(), new BacteryTricolorRule(), new BacteryColoredMarblesRule()];

        foreach ($rules as $rule) {
            $this->assertFalse($rule->validate($event));
            $this->assertFalse($rule->evaluate($event, $this->progress(7))->changed);
        }
    }

    public function test_the_rules_only_support_bactery(): void
    {
        $this->assertTrue((new BacteryTotalStarsRule())->supports($this->event()));
        $this->assertFalse((new BacteryTotalStarsRule())->supports(new GameRunCompleted(new User(), new Game(['name' => 'Binary']), new Run(), [])));
    }

    /**
     * @param  array<string, mixed>  $stats
     */
    private function event(array $stats = [], int $score = 14050): GameRunCompleted
    {
        $run = new Run();
        $run->score = $score;

        return new GameRunCompleted(new User(), new Game(['name' => 'Bactery']), $run, array_replace(['k' => 60, 'm' => 20, 'w' => 18, 'b' => 2, 'n' => 12], $stats));
    }

    private function progress(int $value = 0): UserAchievementProgress
    {
        return new UserAchievementProgress(['current_value' => $value, 'completed_level' => 0]);
    }
}
