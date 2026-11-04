<?php

namespace App\Filament\Widgets;

use App\Services\VisitService;
use Filament\Widgets\ChartWidget;
use Illuminate\Support\Facades\Cache;

// the visits of the last days on a chart. Colours: the validated categorical order of the dataviz skill, each value keeps
// its own whatever the others do
abstract class VisitsChart extends ChartWidget
{
    // (on the page App\Filament\Pages\AudienceDashboard only)
    protected static bool $isDiscovered = false;

    public const COLORS = ['#2a78d6', '#eb6834', '#1baf7a', '#eda100', '#e87ba4', '#6250d6'];

    // what is not a value of its own: « Autres », « Inconnu » (muted of the same palette)
    protected const COLOR_OTHER = '#898781';

    private const PERIODS = [7 => '7 derniers jours', 30 => '30 derniers jours', 90 => '90 derniers jours'];

    public ?string $filter = '30';

    // grouped over the visits: computed again at most every 5 minutes by period, not polled
    protected ?string $pollingInterval = null;

    protected function getFilters(): ?array
    {
        return self::PERIODS;
    }

    // [value => players], the most seen first
    protected function visitors(string $column): array
    {
        $days = isset(self::PERIODS[(int) $this->filter]) ? (int) $this->filter : 30;

        return Cache::remember("admin.widgets.visits.{$column}.{$days}", 300, fn () => app(VisitService::class)->visitorsBy($column, $days));
    }

    // a doughnut: its parts, with their share in the legend (what tells apart the colours close to the background)
    protected function parts(array $counts, array $colors): array
    {
        $total = array_sum($counts);

        return [
            'datasets' => [[
                'data' => array_values($counts),
                'backgroundColor' => array_values($colors),
                'borderWidth' => 0,
                'spacing' => 2,
            ]],
            'labels' => array_map(
                fn ($name, $count) => sprintf('%s (%s %%)', $name, $total ? round($count / $total * 100) : 0),
                array_keys($counts),
                $counts,
            ),
        ];
    }

    protected function doughnutOptions(): array
    {
        return [
            'cutout' => '65%',
            'plugins' => ['legend' => ['position' => 'bottom']],
            'scales' => ['x' => ['display' => false], 'y' => ['display' => false]],
        ];
    }
}
