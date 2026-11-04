<?php

namespace App\Filament\Widgets;

use App\Models\SiteVisit;
use App\Services\VisitService;
use Filament\Forms\Components\DatePicker;
use Filament\Schemas\Schema;
use Filament\Widgets\ChartWidget;
use Filament\Widgets\ChartWidget\Concerns\HasFiltersSchema;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;

class VisitsOverTimeChart extends ChartWidget
{
    use HasFiltersSchema;

    // (on the page App\Filament\Pages\AudienceDashboard only)
    protected static bool $isDiscovered = false;

    protected ?string $heading = 'Fréquentation par jour';

    protected ?string $description = 'Joueurs connectés, chacun une fois par jour. Historique de '.SiteVisit::KEEP_DAYS.' jours.';

    protected int|string|array $columnSpan = 'full';

    protected ?string $maxHeight = '300px';

    // grouped over the visits: computed again at most every 5 minutes by filters, not polled
    protected ?string $pollingInterval = null;

    protected function getData(): array
    {
        return Cache::remember('admin.widgets.visits_over_time.'.md5(json_encode($this->filters)), 300, fn () => $this->computeData());
    }

    private function computeData(): array
    {
        // (nothing is kept before, and nothing happened yet after)
        $oldest = today()->subDays(SiteVisit::KEEP_DAYS);
        $from = Carbon::parse(data_get($this->filters, 'startDate') ?? today()->subDays(30))->max($oldest);
        $to = Carbon::parse(data_get($this->filters, 'endDate') ?? today())->min(today());

        $days = app(VisitService::class)->visitorsPerDay($from, $to);

        return [
            'datasets' => [[
                'label' => 'Visiteurs',
                'data' => array_values($days),
                'borderColor' => VisitsChart::COLORS[0],
                'backgroundColor' => VisitsChart::COLORS[0],
                'borderWidth' => 2,
                'pointRadius' => 2,
                'pointHoverRadius' => 5,
            ]],
            'labels' => array_map(fn (string $day) => Carbon::parse($day)->format('d/m'), array_keys($days)),
        ];
    }

    public function filtersSchema(Schema $schema): Schema
    {
        return $schema->components([
            DatePicker::make('startDate')->label('Du')->default(now()->subDays(30))->minDate(now()->subDays(SiteVisit::KEEP_DAYS))->maxDate(now()),
            DatePicker::make('endDate')->label('Au')->default(now())->minDate(now()->subDays(SiteVisit::KEEP_DAYS))->maxDate(now()),
        ]);
    }

    protected function getOptions(): array
    {
        return [
            'plugins' => ['legend' => ['display' => false]],
            'scales' => [
                'x' => ['grid' => ['display' => false]],
                'y' => ['beginAtZero' => true, 'ticks' => ['precision' => 0]],
            ],
        ];
    }

    protected function getType(): string
    {
        return 'line';
    }
}
