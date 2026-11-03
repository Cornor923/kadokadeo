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
            achievements_enabled: @json(app(App\Settings\SiteSettings::class)->achievements_enabled),
            // the clans are open (App\Settings\ClanSettings::$enabled), else their pages say "Prochainement disponible"
            clans_enabled: @json((bool) app(App\Settings\ClanSettings::class)->enabled),
            // the realtime (App\Support\Realtime), null: the pages poll
            reverb: @json(App\Support\Realtime::clientConfig()),
        }
        window.evts = new EventTarget();
        // window.evts.addEventListener('score', console.log);
        // window.evts.addEventListener('gameFinished', console.log);
    </script>

    {{-- PIXI and its filters, served by the site (public/vendor/<package>/<version>); deferred, they still run before
         the modules of Vite below (in the order of the page): main.js and the games find PIXI --}}
    <script defer src="/vendor/pixi.js/6.0.2/pixi.min.js"></script>
    <script defer src="/vendor/pixi-filters/5.0.0/pixi-filters.min.js"></script>
    @if (file_exists(public_path('build/manifest.json')) || file_exists(public_path('hot')))
        @vite(['resources/css/app.css', 'resources/js/main.js'])
    @endif
</head>

<body>
    @include('components.validation-errors')
    <div id="app" class="w-full"></div>
</body>

</html>
