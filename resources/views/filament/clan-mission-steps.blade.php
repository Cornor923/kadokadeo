{{-- the steps of a mission of a clan, in the admin (App\Filament\Resources\Clans\RelationManagers\MissionsRelationManager) --}}
@php
    $stars = [-1 => 'grise', 0 => 'verte', 1 => 'orange', 2 => 'rouge'];
@endphp
<table style="width: 100%; font-size: .875rem; border-collapse: collapse">
    <thead>
        <tr style="text-align: left; border-bottom: 1px solid rgba(127, 127, 127, .3)">
            <th style="padding: .25rem .5rem">Jeu</th>
            <th style="padding: .25rem .5rem; text-align: right">Score à atteindre</th>
            <th style="padding: .25rem .5rem">Étoile</th>
            <th style="padding: .25rem .5rem">Étape</th>
        </tr>
    </thead>
    <tbody>
        @foreach ($steps as $step)
            @php
                $star = $step->game->getStarFromScore($step->target_score);
                $beyond = $step->target_score > max($step->game->stars ?: [PHP_INT_MAX]);
                $state = match (true) {
                    $step->skipped => 'Passée',
                    $step->completed_at !== null => 'Réussie par '.($step->completedBy?->display_name ?? '?').' ('.number_format($step->score, 0, ',', ' ').')',
                    $step->reservedBy !== null => 'À faire, réservée par '.$step->reservedBy->display_name,
                    default => 'À faire',
                };
            @endphp
            <tr style="border-bottom: 1px solid rgba(127, 127, 127, .15)">
                <td style="padding: .25rem .5rem">{{ $step->game->name }}</td>
                <td style="padding: .25rem .5rem; text-align: right; white-space: nowrap">{{ number_format($step->target_score, 0, ',', ' ') }}</td>
                <td style="padding: .25rem .5rem; white-space: nowrap">{{ ($stars[$star] ?? '?').($beyond ? ' +' : '') }}</td>
                <td style="padding: .25rem .5rem">{{ $state }}</td>
            </tr>
        @endforeach
    </tbody>
</table>
