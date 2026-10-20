{{-- what the detections of the game do to a run (App\Settings\AntiCheatSettings), in the modal of the queue of the suspicious runs --}}
<div style="display: grid; gap: 1rem">
    <div>
        <p style="font-weight: 600">Marquées triche automatiquement</p>
        <p style="font-size: .875rem; opacity: .75">Retirées des classements, sans étoiles ni points de contrat. Elles n’apparaissent pas ici.</p>
        <ul style="list-style: disc; padding-inline-start: 1.25rem">
            @forelse ($hard as $bit)
                <li>{{ $bit->getLabel() }} <span style="opacity: .6">(0x{{ strtoupper(dechex($bit->value)) }})</span></li>
            @empty
                <li>Aucune</li>
            @endforelse
        </ul>
    </div>
    <div>
        <p style="font-weight: 600">Envoyées ici pour examen</p>
        <p style="font-size: .875rem; opacity: .75">Des extensions du navigateur peuvent aussi les déclencher.</p>
        <ul style="list-style: disc; padding-inline-start: 1.25rem">
            @forelse ($soft as $bit)
                <li>{{ $bit->getLabel() }} <span style="opacity: .6">(0x{{ strtoupper(dechex($bit->value)) }})</span></li>
            @empty
                <li>Aucune</li>
            @endforelse
        </ul>
    </div>
    <div>
        <p style="font-weight: 600">Ignorées</p>
        <p style="font-size: .875rem; opacity: .75">Trop fréquentes sur les navigateurs mobiles. Elles restent visibles dans le détail de la partie.</p>
        <ul style="list-style: disc; padding-inline-start: 1.25rem">
            @forelse ($ignored as $bit)
                <li>{{ $bit->getLabel() }} <span style="opacity: .6">(0x{{ strtoupper(dechex($bit->value)) }})</span></li>
            @empty
                <li>Aucune</li>
            @endforelse
        </ul>
    </div>
    <p style="font-size: .875rem; opacity: .75">Les règles du serveur (score très au-dessus de l’historique, record dans le haut du classement, partie plus longue que le temps réel, analyse des coups) ne sanctionnent jamais : elles envoient la partie ici.</p>
    <p style="font-size: .875rem">
        Réglages : <a href="{{ \App\Filament\Pages\ManageAntiCheatSettings::getUrl() }}" style="text-decoration: underline">Paramètres &gt; Anti-triche</a>
    </p>
</div>
