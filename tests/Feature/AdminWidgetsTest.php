<?php

namespace Tests\Feature;

use App\Filament\Widgets\CompletedRunsPerGameChart;
use App\Filament\Widgets\RunsPlayedChart;
use App\Filament\Widgets\StatsOverview;
use App\Models\Game;
use App\Models\Run;
use App\Models\User;
use Flowframe\Trend\Trend;
use Flowframe\Trend\TrendValue;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Livewire\Livewire;
use Tests\TestCase;

class AdminWidgetsTest extends TestCase
{
    use RefreshDatabase;

    private function invoke(object $widget, string $method): mixed
    {
        return (fn () => $this->{$method}())->call($widget);
    }

    public function test_the_dashboard_widgets_are_not_polled(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));

        foreach ([StatsOverview::class, RunsPlayedChart::class, CompletedRunsPerGameChart::class] as $widget) {
            $this->assertNull($this->invoke(Livewire::test($widget)->instance(), 'getPollingInterval'), $widget);
        }
    }

    // the runs of this month, not the ones of the same month a year ago
    public function test_the_stats_count_the_current_month_only(): void
    {
        $this->travelTo(Carbon::parse('2026-10-19 12:00:00'));
        $this->actingAs(User::factory()->create(['is_admin' => true, 'created_at' => '2026-01-01']));
        $player = User::factory()->create(['created_at' => '2026-10-02']);
        Run::factory()->for($player)->create(['created_at' => '2026-10-05']);
        Run::factory()->for($player)->create(['created_at' => '2026-09-30 23:00:00']);
        Run::factory()->create(['created_at' => '2025-10-10']);
        Run::factory()->for($player)->create(['created_at' => '2026-10-06', 'completed_at' => null]);

        $stats = collect($this->invoke(Livewire::test(StatsOverview::class)->instance(), 'getStats'))
            ->mapWithKeys(fn ($stat) => [$stat->getLabel() => [$stat->getValue(), $stat->getDescription()]]);

        $this->assertSame([1, '+0 par rapport au mois dernier'], $stats['Parties terminées ce mois-ci']);
        $this->assertSame([1, '+0 par rapport au mois dernier'], $stats['Joueurs actifs ce mois-ci']);
    }

    // one query for every game, the same days and counts as a Trend by game
    public function test_the_completed_runs_per_game_match_a_trend_by_game(): void
    {
        $this->travelTo(Carbon::parse('2026-10-19 12:00:00'));
        $this->actingAs(User::factory()->create(['is_admin' => true]));
        [$a, $b] = Game::factory()->count(2)->create();
        Game::factory()->create(['is_active' => false]);
        Run::factory()->count(2)->for($a)->create(['created_at' => '2026-10-10 08:00:00']);
        Run::factory()->for($a)->create(['created_at' => '2026-10-12 08:00:00']);
        Run::factory()->for($b)->create(['created_at' => '2026-10-12 09:00:00']);
        Run::factory()->for($b)->create(['created_at' => '2026-10-12 10:00:00', 'completed_at' => null]);

        $widget = Livewire::test(CompletedRunsPerGameChart::class)->set('filters', ['startDate' => '2026-10-01', 'endDate' => '2026-10-19'])->instance();
        $data = $this->invoke($widget, 'getData');

        $trend = fn (Game $game) => Trend::query(Run::whereNotNull('completed_at')->where('game_id', $game->id))
            ->between(start: Carbon::parse('2026-10-01')->startOfDay(), end: Carbon::parse('2026-10-19')->endOfDay())
            ->perDay()
            ->count();
        $this->assertSame($trend($a)->map(fn (TrendValue $value) => $value->date)->all(), $data['labels']);
        $this->assertSame([$a->name, $b->name], array_column($data['datasets'], 'label'));
        foreach ([$a, $b] as $index => $game) {
            $this->assertEquals($trend($game)->map(fn (TrendValue $value) => $value->aggregate)->all(), $data['datasets'][$index]['data']);
        }
        $this->assertSame(2, $data['datasets'][0]['data'][9]);
    }
}
