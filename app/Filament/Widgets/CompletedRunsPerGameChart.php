<?php

namespace App\Filament\Widgets;

use App\Models\Game;
use App\Models\Run;
use Carbon\Carbon;
use Filament\Forms\Components\DatePicker;
use Filament\Schemas\Schema;
use Filament\Widgets\ChartWidget;
use Filament\Widgets\ChartWidget\Concerns\HasFiltersSchema;
use Flowframe\Trend\Trend;
use Flowframe\Trend\TrendValue;
use Illuminate\Support\Facades\Cache;

class CompletedRunsPerGameChart extends ChartWidget
{
    use HasFiltersSchema;

    protected ?string $heading = 'Parties terminées par jeu';

    // counts over the runs table: computed again at most every 5 minutes by filters, not polled
    protected ?string $pollingInterval = null;

    protected function getData(): array
    {
        $startDate = data_get($this->filters, 'startDate') ?? now()->subDays(30)->toDateString();
        $endDate = data_get($this->filters, 'endDate') ?? now()->toDateString();

        return Cache::remember("admin.widgets.completed_runs_per_game.{$startDate}.{$endDate}", 300, fn () => $this->computeData($startDate, $endDate));
    }

    private function computeData(string $startDate, string $endDate): array
    {
        $games = Game::where('is_active', true)->get();

        // the days of every game in one query, grouped like Trend does (its SQL date format, its empty days)
        $trend = new class(Run::query()) extends Trend
        {
            public function sqlDate(): string
            {
                return $this->getSqlDate();
            }
        };
        $trend->between(
            start: Carbon::parse($startDate)->startOfDay(),
            end: Carbon::parse($endDate)->endOfDay(),
        )->perDay();
        $counts = Run::query()
            ->toBase()
            ->selectRaw("game_id, {$trend->sqlDate()} as date, count(*) as aggregate")
            ->whereNotNull('completed_at')
            ->whereIn('game_id', $games->modelKeys())
            ->whereBetween('created_at', [$trend->start, $trend->end])
            ->groupBy('game_id', 'date')
            ->orderBy('date')
            ->get()
            ->groupBy('game_id');

        $datasets = [];
        $labels = null;
        $total = $games->count();

        foreach ($games as $index => $game) {
            $values = $trend->mapValuesToDates($counts->get($game->id, collect()));

            if ($labels === null) {
                $labels = $values->map(fn (TrendValue $value) => $value->date)->all();
            }

            $hue = $total > 1 ? (int) round($index * 360 / $total) : 200;
            $color = "hsl({$hue}, 70%, 50%)";

            $datasets[] = [
                'label' => $game->name,
                'data' => $values->map(fn (TrendValue $value) => $value->aggregate)->all(),
                'borderColor' => $color,
                'backgroundColor' => $color,
            ];
        }

        return [
            'datasets' => $datasets,
            'labels' => $labels ?? [],
        ];
    }

    public function filtersSchema(Schema $schema): Schema
    {
        return $schema->components([
            DatePicker::make('startDate')->label('Du')->default(now()->subDays(30)),
            DatePicker::make('endDate')->label('Au')->default(now()),
        ]);
    }

    protected function getType(): string
    {
        return 'line';
    }
}
