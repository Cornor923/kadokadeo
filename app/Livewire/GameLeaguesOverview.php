<?php

namespace App\Livewire;

use App\Models\League;
use App\Models\LeagueMembership;
use App\Models\Period;
use Filament\Widgets\ChartWidget;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

class GameLeaguesOverview extends ChartWidget
{
    protected ?string $heading = 'Répartition par ligue';

    // not polled (every 5 s by default)
    protected ?string $pollingInterval = null;

    public ?Model $record = null;

    protected array $colors = [
        1 => 'rgba(255, 135, 50, 0.2)',
        2 => 'rgba(210, 90, 40, 0.2)',
        3 => 'rgba(90, 170, 200, 0.2)',
        4 => 'rgba(255, 255, 100, 0.2)',
        5 => 'rgba(205, 175, 130, 0.2)',
    ];

    // protected int|string|array $columnSpan = 2;

    protected function getData(): array
    {
        $periodId = Period::current()->first()?->id;
        $countsByLeague = collect();

        if ($periodId) {
            $highestMemberships = LeagueMembership::query()
                ->select([
                    'league_memberships.user_id',
                    'league_memberships.league_id',
                ])
                ->selectRaw('ROW_NUMBER() OVER (PARTITION BY league_memberships.user_id ORDER BY leagues.level DESC) AS league_rank')
                ->join('leagues', 'leagues.id', '=', 'league_memberships.league_id')
                ->where('league_memberships.game_id', $this->record?->id)
                ->where('league_memberships.period_id', $periodId);

            $countsByLeague = DB::query()
                ->fromSub($highestMemberships, 'highest_memberships')
                ->where('league_rank', 1)
                ->select('league_id')
                ->selectRaw('COUNT(*) AS players_count')
                ->groupBy('league_id')
                ->pluck('players_count', 'league_id');
        }

        $leaguesData = League::query()
            ->orderBy('level', 'asc')
            ->get()
            ->map(fn ($league) => [
                'label' => $league->name,
                'data' => $countsByLeague->get($league->id, 0),
            ])
            ->values()
            ->all();

        return [
            'datasets' => [
                [
                    'label' => 'Joueurs',
                    'data' => array_column($leaguesData, 'data'),
                    'backgroundColor' => array_values($this->colors),
                    'borderColor' => array_map(fn ($color) => str_replace('0.2', '1', $color), array_values($this->colors)),
                ],
            ],
            'labels' => array_column($leaguesData, 'label'),
        ];
    }

    protected function getType(): string
    {
        return 'bar';
    }
}
