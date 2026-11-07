<?php

namespace Tests\Unit;

use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Rules\Games\Pioutch\PioutchCleanScoreRule;
use App\Achievements\Rules\Games\Pioutch\PioutchFuriesUsedRule;
use App\Achievements\Rules\Games\Pioutch\PioutchFuryStockRule;
use App\Achievements\Rules\Games\Pioutch\PioutchLostRule;
use App\Achievements\Rules\Games\Pioutch\PioutchSavedRule;
use App\Achievements\Rules\Games\Pioutch\PioutchVioletLostRule;
use App\Models\Game;
use App\Models\Run;
use App\Models\User;
use App\Models\UserAchievementProgress;
use Tests\TestCase;

class PioutchAchievementRulesTest extends TestCase
{
    // a game: 40 birds shot, 30 saved, the 5 lost (one violet), 2 furies used, 21.000 points before the first mistake
    private const STATS = ['c' => 40, 's' => 30, 'l' => 5, 'f' => 2, 'lt' => [3, 1, 1, 0], 'fs' => 21000, 'mf' => 4];

    public function test_the_counts_add_up(): void
    {
        $this->assertSame(12, (new PioutchSavedRule())->evaluate($this->event(['s' => 10, 'c' => 40]), $this->progress(2))->progress);
        $this->assertSame(7, (new PioutchLostRule())->evaluate($this->event([]), $this->progress(2))->progress);
        $this->assertSame(5, (new PioutchFuriesUsedRule())->evaluate($this->event([]), $this->progress(3))->progress);
    }

    public function test_a_violet_lost(): void
    {
        $rule = new PioutchVioletLostRule();

        $this->assertSame(1, $rule->evaluate($this->event([]), $this->progress())->progress);
        $this->assertSame(0, $rule->evaluate($this->event(['lt' => [4, 1, 0, 0]]), $this->progress())->progress);
    }

    public function test_the_score_before_the_first_bird_lost_or_the_first_fury(): void
    {
        $rule = new PioutchCleanScoreRule();

        $this->assertSame(21000, $rule->evaluate($this->event([]), $this->progress())->progress);
        $this->assertSame(0, $rule->evaluate($this->event(['fs' => 0]), $this->progress())->progress);
        // (no bird lost and no fury: the whole score)
        $this->assertSame(30000, $rule->evaluate($this->event(['l' => 0, 'f' => 0, 'lt' => [0, 0, 0, 0], 'fs' => -1]), $this->progress())->progress);
        $this->assertSame(25000, $rule->evaluate($this->event([]), $this->progress(25000))->progress);
    }

    public function test_the_most_furies_held_at_once(): void
    {
        $rule = new PioutchFuryStockRule();

        $this->assertSame(4, $rule->evaluate($this->event([]), $this->progress())->progress);
        $this->assertSame(5, $rule->evaluate($this->event([]), $this->progress(5))->progress);
    }

    public function test_the_stats_must_hold_together(): void
    {
        $rule = new PioutchSavedRule();

        $this->assertTrue($rule->validate($this->event([])));
        // the stats of the game before its achievements
        $this->assertFalse($rule->validate($this->event([], ['c' => 40, 's' => 30, 'l' => 5])));
        $this->assertFalse($rule->validate($this->event(['lt' => [3, 1, 0, 0]])));
        $this->assertFalse($rule->validate($this->event(['s' => 36])));
        $this->assertFalse($rule->validate($this->event(['l' => 6, 'lt' => [4, 1, 1, 0]])));
        $this->assertFalse($rule->validate($this->event(['mf' => 2])));
        $this->assertFalse($rule->validate($this->event(['fs' => 30001])));
        $this->assertFalse($rule->validate($this->event(['fs' => -1])));
        $this->assertFalse($rule->validate($this->event(['l' => 0, 'f' => 0, 'lt' => [0, 0, 0, 0], 'fs' => 100])));
    }

    private function event(array $changes, ?array $stats = null): GameRunCompleted
    {
        return new GameRunCompleted(new User(), Game::query()->make(['name' => 'Pioutch']), new Run(['score' => 30000]), array_replace($stats ?? self::STATS, $changes));
    }

    private function progress(int $value = 0): UserAchievementProgress
    {
        return new UserAchievementProgress(['current_value' => $value, 'completed_level' => 0]);
    }
}
