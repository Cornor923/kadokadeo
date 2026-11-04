<?php

namespace App\Filament\Widgets;

use App\Models\SiteVisit;

class VisitsByBrowserChart extends VisitsChart
{
    protected ?string $heading = 'Navigateurs';

    protected ?string $maxHeight = '260px';

    // App\Support\UserAgent::browser
    private const BROWSERS = ['Chrome', 'Firefox', 'Safari', 'Edge', 'Opera'];

    protected function getType(): string
    {
        return 'doughnut';
    }

    protected function getData(): array
    {
        $visitors = $this->visitors('browser');
        $counts = $colors = [];
        foreach (self::BROWSERS as $i => $browser) {
            $counts[$browser] = $visitors[$browser] ?? 0;
            $colors[] = self::COLORS[$i];
        }
        $counts[SiteVisit::UNKNOWN_BROWSER] = $visitors[SiteVisit::UNKNOWN_BROWSER] ?? 0;
        $colors[] = self::COLOR_OTHER;

        return $this->parts($counts, $colors);
    }

    protected function getOptions(): array
    {
        return $this->doughnutOptions();
    }
}
