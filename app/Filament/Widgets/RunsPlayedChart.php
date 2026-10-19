<?php

namespace App\Filament\Widgets;

use App\Models\Game;
use App\Models\Run;
use Carbon\Carbon;
use Filament\Forms\Components\DatePicker;
use Filament\Forms\Components\Select;
use Filament\Schemas\Schema;
use Filament\Widgets\ChartWidget;
use Filament\Widgets\ChartWidget\Concerns\HasFiltersSchema;
use Flowframe\Trend\Trend;
use Flowframe\Trend\TrendValue;
use Illuminate\Support\Facades\Cache;

class RunsPlayedChart extends ChartWidget
{
    use HasFiltersSchema;

    protected ?string $heading = 'Parties jouées';

    // counts over the runs table: computed again at most every 5 minutes by filters, not polled
    protected ?string $pollingInterval = null;

    protected function getData(): array
    {
        return Cache::remember('admin.widgets.runs_played.'.md5(json_encode($this->filters)), 300, fn () => $this->computeData());
    }

    private function computeData(): array
    {
        $startDate = data_get($this->filters, 'startDate');
        $endDate = data_get($this->filters, 'endDate');
        $game = data_get($this->filters, 'game');
        $period = data_get($this->filters, 'period');

        $runQ = Run::query()->when($game, function ($query) use ($game) {
            return $query->where('game_id', $game);
        });

        $dataCompleted = Trend::query($runQ->clone()->whereNotNull('completed_at'))
            ->between(
                start: Carbon::parse($startDate)->startOfDay(),
                end: Carbon::parse($endDate)->endOfDay(),
            );
        $dataNotCompleted = Trend::query($runQ->clone()->whereNull('completed_at'))
            ->between(
                start: Carbon::parse($startDate)->startOfDay(),
                end: Carbon::parse($endDate)->endOfDay(),
            );
        match ($period) {
            'day' => [$dataCompleted->perDay(), $dataNotCompleted->perDay()],
            'week' => [$dataCompleted->perWeek(), $dataNotCompleted->perWeek()],
            'month' => [$dataCompleted->perMonth(), $dataNotCompleted->perMonth()],
            'year' => [$dataCompleted->perYear(), $dataNotCompleted->perYear()],
            default => [$dataCompleted->perMonth(), $dataNotCompleted->perMonth()]
        };

        $dataCompleted = $dataCompleted->count();
        $dataNotCompleted = $dataNotCompleted->count();

        return [
            'datasets' => [
                [
                    'label' => 'Parties terminées',
                    'data' => $dataCompleted->map(fn (TrendValue $value) => $value->aggregate)->all(),
                    'borderColor' => '#11AA55',
                ],
                [
                    'label' => 'Parties non terminées',
                    'data' => $dataNotCompleted->map(fn (TrendValue $value) => $value->aggregate)->all(),
                    'borderColor' => '#AA1155',
                ],
                [
                    'label' => 'Total des parties',
                    'data' => $dataNotCompleted->map(fn (TrendValue $value, $key) => $value->aggregate + ($dataCompleted[$key]?->aggregate ?? 0))->all(),
                ],
            ],
            'labels' => $dataCompleted->map(fn (TrendValue $value) => $value->date)->all(),
        ];
    }

    public function filtersSchema(Schema $schema): Schema
    {
        return $schema->components([
            DatePicker::make('startDate')->label('Du')->default(now()->subDays(30)),
            DatePicker::make('endDate')->label('Au')->default(now()),
            // Select::make('status')
            //     ->label('Run status')
            //     ->options([
            //         'complete' => 'Complete',
            //         'incomplete' => 'Incomplete',
            //     ])
            //     ->default(null),
            Select::make('period')
                ->label('Période')
                ->options([
                    'day' => 'Jour',
                    'week' => 'Semaine',
                    'month' => 'Mois',
                    'year' => 'Année',
                ])
                ->default('day'),
            Select::make('game')
                ->label('Jeu')
                ->options(Game::where('is_active', true)->pluck('name', 'id'))
                ->default(null),
        ]);
    }

    protected function getType(): string
    {
        return 'line';
    }
}
