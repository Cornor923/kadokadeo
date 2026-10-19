<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">

<head>
    <meta charset="utf-8" />
    <title>@yield('title', 'KadoKadéo')</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <script type="text/javascript">
        window.Kado = {
            public_key: '{{ str_replace("\n", "\\n", app(App\Services\RunService::class)->getPublicKey()) }}',
            achievements_enabled: @json((bool) config('kado.achievements.enabled')),
            // the clans are open (App\Settings\ClanSettings::$enabled), else their pages say "Prochainement disponible"
            clans_enabled: @json((bool) app(App\Settings\ClanSettings::class)->enabled),
        }
        window.evts = new EventTarget();
        // window.evts.addEventListener('score', console.log);
        // window.evts.addEventListener('gameFinished', console.log);
    </script>

    @if (file_exists(public_path('build/manifest.json')) || file_exists(public_path('hot')))
        @vite(['resources/css/app.css', 'resources/js/main.js'])
    @endif
    <script src="https://cdnjs.cloudflare.com/ajax/libs/pixi.js/6.0.2/browser/pixi.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/pixi-filters@5.0.0/dist/browser/pixi-filters.min.js"></script>
</head>

<body>
    @include('components.validation-errors')
    <div id="app" class="w-full"></div>
</body>

</html>
