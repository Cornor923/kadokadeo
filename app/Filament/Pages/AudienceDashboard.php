<?php

namespace App\Filament\Pages;

use App\Filament\Widgets\LiveVisitors;
use App\Filament\Widgets\VisitsByBrowserChart;
use App\Filament\Widgets\VisitsByCountryChart;
use App\Filament\Widgets\VisitsByDeviceChart;
use App\Filament\Widgets\VisitsOverTimeChart;
use BackedEnum;
use Filament\Pages\Dashboard;
use Filament\Support\Icons\Heroicon;

// the audience of the site (App\Services\VisitService), a dashboard of its own: its widgets are not on the main one
class AudienceDashboard extends Dashboard
{
    protected static string $routePath = 'frequentation';

    protected static ?string $title = 'Fréquentation';

    protected static ?string $navigationLabel = 'Fréquentation';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedChartBar;

    // (right after the main dashboard)
    protected static ?int $navigationSort = -1;

    public function getWidgets(): array
    {
        return [
            LiveVisitors::class,
            VisitsOverTimeChart::class,
            VisitsByDeviceChart::class,
            VisitsByBrowserChart::class,
            VisitsByCountryChart::class,
        ];
    }
}
