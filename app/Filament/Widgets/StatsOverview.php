<?php

namespace App\Filament\Widgets;

use App\Models\Run;
use App\Models\User;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Illuminate\Support\Facades\Cache;

class StatsOverview extends StatsOverviewWidget
{
    // counts over the whole runs table: computed again at most every 5 minutes, not polled
    protected ?string $pollingInterval = null;

    private const CACHE_SECONDS = 300;

    protected function getStats(): array
    {
        $stats = Cache::remember('admin.widgets.stats_overview', self::CACHE_SECONDS, function () {
            $thisMonth = [now()->startOfMonth(), now()->endOfMonth()];
            $prevMonth = [now()->subMonthNoOverflow()->startOfMonth(), now()->subMonthNoOverflow()->endOfMonth()];
            $completedRuns = fn (array $month) => Run::query()->whereBetween('created_at', $month)->whereNotNull('completed_at');

            return [
                'runs' => $completedRuns($thisMonth)->count(),
                'runs_prev' => $completedRuns($prevMonth)->count(),
                'users' => User::query()->count(),
                'users_month' => User::query()->whereBetween('created_at', $thisMonth)->count(),
                'players' => $completedRuns($thisMonth)->distinct()->count('user_id'),
                'players_prev' => $completedRuns($prevMonth)->distinct()->count('user_id'),
            ];
        });

        $increase = $stats['runs'] - $stats['runs_prev'];
        $activePlayersIncrease = $stats['players'] - $stats['players_prev'];

        return [
            Stat::make('Parties terminées ce mois-ci', $stats['runs'])
                ->description(($increase >= 0 ? '+' : '').$increase.' par rapport au mois dernier')
                ->descriptionIcon($increase >= 0 ? 'heroicon-m-arrow-trending-up' : 'heroicon-m-arrow-trending-down'),
            Stat::make('Utilisateurs', $stats['users'])
                ->description('+'.$stats['users_month'].' ce mois-ci'),
            Stat::make('Joueurs actifs ce mois-ci', $stats['players'])
                ->description(($activePlayersIncrease >= 0 ? '+' : '').$activePlayersIncrease.' par rapport au mois dernier'),
        ];
    }
}
