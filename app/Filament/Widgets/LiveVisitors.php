<?php

namespace App\Filament\Widgets;

use App\Services\VisitService;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

// who is on the site now (App\Services\VisitService), on the page App\Filament\Pages\AudienceDashboard only
class LiveVisitors extends StatsOverviewWidget
{
    protected static bool $isDiscovered = false;

    protected ?string $pollingInterval = '30s';

    private const ACTIVE_MINUTES = 15;

    protected function getStats(): array
    {
        $visits = app(VisitService::class);
        $connected = $visits->connectedNow();

        return [
            Stat::make('Connectés maintenant', $connected ?? '—')
                ->description($connected === null ? 'temps réel indisponible' : 'une page ouverte, même en arrière-plan')
                ->color($connected === null ? 'gray' : 'success'),
            Stat::make('Actifs (15 min)', $visits->activeSince(self::ACTIVE_MINUTES))
                ->description('une requête au site dans ce délai'),
            Stat::make('Visiteurs aujourd\'hui', $visits->visitorsBetween(today()))
                ->description('hier : '.$visits->visitorsBetween(today()->subDay(), today()->subDay())),
            Stat::make('Visiteurs (7 jours)', $visits->visitorsBetween(today()->subDays(6)))
                ->description('joueurs connectés, chacun une fois'),
        ];
    }
}
