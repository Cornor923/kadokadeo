<?php

namespace Tests\Unit;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Rules\Games\XianXiang\XianXiangMinScoreRule;
use App\Achievements\Rules\Games\XianXiang\XianXiangNoOnePointPairRule;
use App\Achievements\Rules\Games\XianXiang\XianXiangPerfectColorsRule;
use App\Achievements\Rules\Games\XianXiang\XianXiangPerfectNeighboursRule;
use App\Achievements\Rules\Games\XianXiang\XianXiangPerfectPairsRule;
use App\Achievements\Rules\Games\XianXiang\XianXiangTotalTilesRule;
use App\Models\Game;
use App\Models\Run;
use App\Models\User;
use App\Models\UserAchievementProgress;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class XianXiangAchievementRulesTest extends TestCase
{
    public function test_a_finished_game_destroys_its_42_tiles(): void
    {
        $result = (new XianXiangTotalTilesRule())->evaluate($this->event(), $this->progress(100));

        $this->assertSame(142, $result->progress);
    }

    public function test_the_perfect_neighbours_add_up(): void
    {
        $result = (new XianXiangPerfectNeighboursRule())->evaluate($this->event(['n' => 3]), $this->progress(10));

        $this->assertSame(13, $result->progress);
    }

    public function test_the_perfect_pairs_keep_the_best_game(): void
    {
        $rule = new XianXiangPerfectPairsRule();

        $this->assertSame(12, $rule->evaluate($this->event(), $this->progress(10))->progress);
        $this->assertSame(14, $rule->evaluate($this->event(), $this->progress(14))->progress);
    }

    public function test_no_one_point_pair_needs_no_pair_without_any_attribute_in_common(): void
    {
        $rule = new XianXiangNoOnePointPairRule();

        $this->assertSame(1, $rule->evaluate($this->event(['c' => [0, 4, 5, 12]]), $this->progress())->progress);
        $this->assertSame(0, $rule->evaluate($this->event(['c' => [1, 3, 5, 12]]), $this->progress())->progress);
    }

    public function test_min_score_is_a_score_of_exactly_21(): void
    {
        $rule = new XianXiangMinScoreRule();
        $stats = ['c' => [21, 0, 0, 0], 'p' => [0, 0, 0, 0], 'n' => 0];

        $this->assertSame(1, $rule->evaluate($this->event($stats, 21), $this->progress())->progress);
        $this->assertSame(0, $rule->evaluate($this->event($stats, 70), $this->progress())->progress);
    }

    public function test_perfect_colors_keeps_the_best_count_of_the_weakest_color(): void
    {
        $rule = new XianXiangPerfectColorsRule();

        $this->assertSame(2, $rule->evaluate($this->event(['p' => [2, 2, 2, 6]]), $this->progress())->progress);
        $this->assertSame(1, $rule->evaluate($this->event(['p' => [1, 3, 2, 6]]), $this->progress())->progress);
        $this->assertSame(2, $rule->evaluate($this->event(['p' => [0, 3, 3, 6]]), $this->progress(2))->progress);
    }

    public function test_the_unique_achievements_stay_obtained(): void
    {
        $event = $this->event(['c' => [1, 3, 5, 12], 'p' => [0, 3, 3, 6]], 1234);

        $this->assertSame(1, (new XianXiangNoOnePointPairRule())->evaluate($event, $this->progress(1))->progress);
        $this->assertSame(1, (new XianXiangMinScoreRule())->evaluate($event, $this->progress(1))->progress);
    }

    /**
     * @return array<string, array{array<string, mixed>}>
     */
    public static function invalidStats(): array
    {
        return [
            'the list of the older builds' => [[0, 3, 9, 9]],
            'no pairs' => [['c' => null]],
            'a pair missing' => [['c' => [1, 3, 5, 11], 'p' => [2, 2, 2, 5]]],
            'three pair kinds' => [['c' => [3, 6, 12]]],
            'a negative count' => [['c' => [-1, 4, 6, 12]]],
            'a count not an integer' => [['c' => [1, 3, 5, '12']]],
            'colors not adding up to the perfect pairs' => [['p' => [2, 2, 2, 5]]],
            'a color missing' => [['p' => [4, 4, 4]]],
            'no neighbours' => [['n' => null]],
            'more neighbours than perfect pairs' => [['n' => 13]],
            'negative neighbours' => [['n' => -1]],
        ];
    }

    /**
     * @param  array<mixed>  $stats
     */
    #[DataProvider('invalidStats')]
    public function test_invalid_stats_give_no_progress(array $stats): void
    {
        $event = array_is_list($stats) ? $this->rawEvent($stats) : $this->event($stats);

        foreach ($this->rules() as $rule) {
            $this->assertFalse($rule->validate($event));
            $this->assertFalse($rule->evaluate($event, $this->progress(7))->changed);
        }
    }

    public function test_the_rules_only_support_xian_xiang(): void
    {
        $this->assertTrue((new XianXiangTotalTilesRule())->supports($this->event()));
        $this->assertFalse((new XianXiangTotalTilesRule())->supports(new GameRunCompleted(new User(), new Game(['name' => 'Binary']), new Run(), [])));
    }

    /**
     * @return list<XianXiangTotalTilesRule|XianXiangPerfectNeighboursRule|XianXiangPerfectPairsRule|XianXiangNoOnePointPairRule|XianXiangMinScoreRule|XianXiangPerfectColorsRule>
     */
    private function rules(): array
    {
        return [
            new XianXiangTotalTilesRule(),
            new XianXiangPerfectNeighboursRule(),
            new XianXiangPerfectPairsRule(),
            new XianXiangNoOnePointPairRule(),
            new XianXiangMinScoreRule(),
            new XianXiangPerfectColorsRule(),
        ];
    }

    /**
     * @param  array<string, mixed>  $stats
     */
    private function event(array $stats = [], int $score = 13551): GameRunCompleted
    {
        return $this->rawEvent(array_replace(['c' => [1, 3, 5, 12], 'p' => [3, 3, 3, 3], 'n' => 2], $stats), $score);
    }

    /**
     * @param  array<mixed>  $stats
     */
    private function rawEvent(array $stats, int $score = 13551): GameRunCompleted
    {
        $run = new Run();
        $run->score = $score;

        return new GameRunCompleted(new User(), new Game(['name' => 'Xian-Xiang']), $run, $stats);
    }

    private function progress(int $value = 0): UserAchievementProgress
    {
        return new UserAchievementProgress(['current_value' => $value, 'completed_level' => 0]);
    }
}
