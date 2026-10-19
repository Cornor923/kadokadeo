{{-- the steps of the missions with the settings of the form, before saving them (App\Filament\Pages\ManageClanSettings::preview) --}}
<div style="display: grid; gap: .5rem">
    <p style="font-weight: 600">Aperçu : les étapes d'une mission pour un clan de {{ $members }} membres</p>
    <p style="font-size: .875rem; opacity: .75">
        L'étoile que rapporte le score à atteindre de chaque étape. Les étapes sont mélangées dans la mission.
    </p>
    <table style="width: 100%; font-size: .875rem; border-collapse: collapse">
        <thead>
            <tr style="text-align: left; border-bottom: 1px solid rgba(127, 127, 127, .3)">
                <th style="padding: .25rem .5rem">Mission</th>
                <th style="padding: .25rem .5rem">Palier le plus haut</th>
                <th style="padding: .25rem .5rem">Étapes</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($rows as $row)
                <tr style="border-bottom: 1px solid rgba(127, 127, 127, .15)">
                    <td style="padding: .25rem .5rem; white-space: nowrap">n° {{ $row['number'] }}</td>
                    <td style="padding: .25rem .5rem; white-space: nowrap">{{ $row['top'] }}</td>
                    <td style="padding: .25rem .5rem">
                        {{ implode(' · ', $row['steps']) }}
                    </td>
                </tr>
            @endforeach
        </tbody>
    </table>
</div>
