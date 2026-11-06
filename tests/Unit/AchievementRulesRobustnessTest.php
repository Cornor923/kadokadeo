<?php

namespace Tests\Unit;

use App\Achievements\AchievementRule;
use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Stats;
use App\Models\Game;
use App\Models\Run;
use App\Models\User;
use App\Models\UserAchievementProgress;
use Random\Engine\Mt19937;
use Random\Randomizer;
use Tests\TestCase;

// The stats of a run are sent by the game, a player can send anything: the rules never fail, whatever is in them. The
// fixture has the stats of a real run of each game (tests/Fixtures/achievement-stats.json), the test breaks them.
class AchievementRulesRobustnessTest extends TestCase
{
    private const NASTY_VALUES = [[], ['a' => 1], 'abc', '1e30', '12', -1, 1.5, true, null, PHP_INT_MAX, Stats::MAX + 1, 1e30, [[]], [1, 2, 3], ['x' => [1]]];

    public function test_each_game_with_rules_has_its_stats_in_the_fixture_and_they_pass_its_rules(): void
    {
        $fixture = $this->fixture();

        foreach ($this->rulesByGame() as $key => $rules) {
            $this->assertArrayHasKey($key, $fixture, "no stats for {$key} in tests/Fixtures/achievement-stats.json");
            $event = $this->event($key, $fixture[$key], $fixture[$key]['stats']);
            foreach ($rules as $rule) {
                $this->assertTrue($rule->validate($event), $rule::class);
            }
        }
    }

    public function test_the_rules_never_fail_on_broken_stats(): void
    {
        $fixture = $this->fixture();
        $random = new Randomizer(new Mt19937(42));

        foreach ($this->rulesByGame() as $key => $rules) {
            $stats = $fixture[$key]['stats'];
            $paths = $this->paths($stats);
            $broken = [];
            // each stat replaced by each value, then at random further in
            foreach (array_keys($stats) as $name) {
                foreach (self::NASTY_VALUES as $value) {
                    $broken[] = [[$name], $this->replaced($stats, [$name], $value)];
                }
                $broken[] = [[$name], array_diff_key($stats, [$name => true])];
            }
            for ($i = 0; $i < 400; $i++) {
                $path = $paths[$random->getInt(0, count($paths) - 1)];
                $broken[] = [$path, match ($random->getInt(0, 2)) {
                    0 => $this->replaced($stats, $path, self::NASTY_VALUES[$random->getInt(0, count(self::NASTY_VALUES) - 1)]),
                    1 => $this->withObjectAt($stats, $path),
                    2 => $this->without($stats, $path),
                }];
            }

            foreach ($broken as [$path, $brokenStats]) {
                $event = $this->event($key, $fixture[$key], $brokenStats);
                foreach ($rules as $rule) {
                    foreach ([0, Stats::MAX] as $current) {
                        try {
                            $result = $rule->evaluate($event, $this->progress($current));
                        } catch (\Throwable $e) {
                            $this->fail(sprintf('%s, %s broken: %s', class_basename($rule), implode('.', $path), $e->getMessage()));
                        }
                        $this->assertGreaterThanOrEqual(0, $result->progress, class_basename($rule));
                        $this->assertLessThanOrEqual(Stats::MAX, $result->progress, class_basename($rule));
                    }
                }
            }
        }
    }

    public function test_a_progress_stays_in_its_column(): void
    {
        $this->assertSame(Stats::MAX, AchievementRuleResult::setProgress(PHP_INT_MAX)->progress);
        $this->assertSame(Stats::MAX, AchievementRuleResult::increment(Stats::MAX, PHP_INT_MAX)->progress);
        $this->assertSame(0, AchievementRuleResult::increment(3, -5)->progress);
    }

    public function test_an_object_is_not_a_list(): void
    {
        $this->assertTrue(Stats::isCounts([0, Stats::MAX], 2));
        $this->assertFalse(Stats::isCounts(['a' => 0, 'b' => 1], 2));
        $this->assertFalse(Stats::isCounts([1 => 0, 2 => 1]));
        $this->assertFalse(Stats::isCounts([-1]));
        $this->assertFalse(Stats::isCounts([Stats::MAX + 1]));
        $this->assertFalse(Stats::isCounts([1.0]));
        $this->assertFalse(Stats::isCounts([1], 2));
        $this->assertTrue(Stats::isRows([[1, 2], [3, 4]], 2));
        $this->assertFalse(Stats::isRows([[1, 2], [3]], 2));
    }

    private function fixture(): array
    {
        return json_decode(file_get_contents(base_path('tests/Fixtures/achievement-stats.json')), true);
    }

    /**
     * @return array<string, list<AchievementRule>>
     */
    private function rulesByGame(): array
    {
        $rules = [];
        foreach (app()->tagged('achievement.rules') as $rule) {
            if ($rule->gameKey() !== null) {
                $rules[$rule->gameKey()][] = $rule;
            }
        }

        return $rules;
    }

    // the paths of the stats, a few items of each list: the first ones are like the others
    private function paths(array $value, array $path = []): array
    {
        $paths = [];
        foreach (array_slice($value, 0, 6, true) as $key => $item) {
            $paths[] = [...$path, $key];
            if (is_array($item)) {
                array_push($paths, ...$this->paths($item, [...$path, $key]));
            }
        }

        return $paths;
    }

    private function replaced(array $stats, array $path, mixed $value): array
    {
        data_set($stats, implode('.', $path), $value);

        return $stats;
    }

    private function without(array $stats, array $path): array
    {
        $last = array_pop($path);
        $parent = $path === [] ? $stats : data_get($stats, implode('.', $path));
        unset($parent[$last]);

        return $path === [] ? $parent : $this->replaced($stats, $path, $parent);
    }

    // the list at this path sent as an object: its items have other keys
    private function withObjectAt(array $stats, array $path): array
    {
        $value = data_get($stats, implode('.', $path));
        if (!is_array($value) || $value === []) {
            return $stats;
        }

        return $this->replaced($stats, $path, array_combine(array_map(fn ($key) => "k{$key}", array_keys($value)), $value));
    }

    private function event(string $key, array $run, array $stats): GameRunCompleted
    {
        return new GameRunCompleted(
            new User(),
            Game::query()->make(['name' => $key]),
            Run::query()->make(['score' => $run['score'], 'play_time_seconds' => $run['play_time_seconds']]),
            $stats,
        );
    }

    private function progress(int $value): UserAchievementProgress
    {
        $progress = new UserAchievementProgress();
        $progress->current_value = $value;
        $progress->completed_level = 0;
        $progress->state = [];

        return $progress;
    }
}
