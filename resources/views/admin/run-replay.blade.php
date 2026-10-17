<!DOCTYPE html>
<html lang="fr">

<head>
    <meta charset="utf-8" />
    <title>Replay</title>
    <script type="text/javascript">
        // a replay sends nothing: no key to encrypt the runs
        window.Kado = { public_key: '' }
        window.evts = new EventTarget();
    </script>
    @if ($player && (file_exists(public_path('build/manifest.json')) || file_exists(public_path('hot'))))
        @vite(['resources/js/replay-player.js'])
    @endif
    <script src="https://cdnjs.cloudflare.com/ajax/libs/pixi.js/6.0.2/browser/pixi.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/pixi-filters@5.0.0/dist/browser/pixi-filters.min.js"></script>
    <style>
        {!! $fontFaces !!}
        html, body { margin: 0; padding: 0; background: #000; overflow: hidden; }
        #game { display: block; -webkit-user-select: none; -webkit-touch-callout: none; width: 600px; height: 640px; touch-action: none; user-select: none; }
        #message { color: #fff; font: 14px sans-serif; padding: 1rem; }
    </style>
</head>

<body>
    @if ($player)
        {{-- the size of resources/js/components/games/GameScript.vue --}}
        @php($arkadeo = $player['game']['is_arkadeo'])
        <canvas id="game" width="{{ $arkadeo ? 600 : 900 }}" height="{{ $arkadeo ? 500 : 960 }}" style="height: {{ $arkadeo ? 500 : 640 }}px"></canvas>
        <div id="message" hidden></div>
        <script type="application/json" id="replay-data">@json($player)</script>
    @else
        <div id="message">Cette partie n’a pas de replay, ou la version de son jeu n’existe plus.</div>
    @endif
</body>

</html>
