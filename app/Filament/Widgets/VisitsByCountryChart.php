<?php

namespace App\Filament\Widgets;

use App\Models\SiteVisit;
use Illuminate\Contracts\Support\Htmlable;
use Illuminate\Support\HtmlString;
use Locale;

class VisitsByCountryChart extends VisitsChart
{
    protected ?string $heading = 'Pays';

    protected int|string|array $columnSpan = 'full';

    protected ?string $maxHeight = '320px';

    private const TOP = 10;

    // the database of App\Support\GeoIp asks for this link (CC BY 4.0) on the pages that use it
    public function getDescription(): string|Htmlable|null
    {
        return new HtmlString('<a href="https://db-ip.com" target="_blank" rel="noopener" style="text-decoration: underline">IP Geolocation by DB-IP</a>');
    }

    protected function getType(): string
    {
        return 'bar';
    }

    protected function getData(): array
    {
        $visitors = $this->visitors('country');
        $unknown = $visitors[SiteVisit::UNKNOWN_COUNTRY] ?? 0;
        unset($visitors[SiteVisit::UNKNOWN_COUNTRY]);

        $rows = [];
        foreach (array_slice($visitors, 0, self::TOP, true) as $country => $count) {
            $rows[] = [Locale::getDisplayRegion("-{$country}", 'fr'), $count, self::COLORS[0]];
        }
        $others = array_sum(array_slice($visitors, self::TOP));
        if ($others > 0) {
            $rows[] = ['Autres', $others, self::COLOR_OTHER];
        }
        if ($unknown > 0) {
            $rows[] = ['Inconnu', $unknown, self::COLOR_OTHER];
        }

        return [
            'datasets' => [[
                'label' => 'Visiteurs',
                'data' => array_column($rows, 1),
                'backgroundColor' => array_column($rows, 2),
                'borderRadius' => 4,
                'maxBarThickness' => 18,
            ]],
            'labels' => array_column($rows, 0),
        ];
    }

    protected function getOptions(): array
    {
        return [
            'indexAxis' => 'y',
            'plugins' => ['legend' => ['display' => false]],
            'scales' => [
                'x' => ['beginAtZero' => true, 'ticks' => ['precision' => 0]],
                'y' => ['grid' => ['display' => false]],
            ],
        ];
    }
}
