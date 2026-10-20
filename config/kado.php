<?php

// what depends on the server only. The settings of the site (games per day, anti cheat, replays...) are in the settings
// table (App\Settings\*), changed from the admin panel (« Paramètres »)
return [
    // the replays of the runs that count are played again on the server in a headless Chrome to check their score
    // (App\Jobs\VerifyRunReplay, turned on in App\Settings\AntiCheatSettings): needs Node 22+ and Chrome
    'replay_verifier' => [
        'node' => env('KADO_REPLAY_VERIFIER_NODE', 'node'),
        // path of Chrome / Chromium (default: looked for at the usual places)
        'browser' => env('KADO_REPLAY_VERIFIER_BROWSER'),
    ],

    // the analyzers of the moves of a game (resources/js/replay-verifier/analyzers/<game_key>.mjs), run by the replay
    // verifier (App\Settings\AntiCheatSettings): the queue of the runs verified for their analysis only
    'replay_analysis' => [
        'queue' => env('KADO_REPLAY_ANALYSIS_QUEUE', 'default'),
    ],

    // the looks of the site (App\Http\Controllers\Api\ThemeController): "base" for everyone, the others bought once with
    // Kado points (their prices: App\Settings\SiteSettings::$theme_prices, this one when a theme has none). Karbon: the
    // second theme of KadoKado (its images were in dat.kadokado.com/gfx/gui/karbon)
    'themes' => [
        'base' => ['name' => 'KadoKado', 'price' => 0],
        'karbon' => ['name' => 'Karbon', 'price' => 10000],
    ],

    // tools to try the clans without other players (/clans/debug: fake attacks, defenses and mission steps, time going by,
    // end of the period). Never in production.
    'debug_tools' => (bool) env('KADO_DEBUG_TOOLS', false) && env('APP_ENV') !== 'production',

    // versions of the game bundles kept for their replays (written by resources/js/games/build-games.mjs, turned on in
    // App\Settings\SiteSettings)
    'game_builds' => [
        'path' => env('KADO_GAME_BUILDS_PATH', storage_path('app/game-builds')),
    ],

    'security' => [
        'private_key_path' => env('KADO_RSA_PRIVATE_KEY_PATH', storage_path('app/private/privkey.pem')),
        'public_key_path' => env('KADO_RSA_PUBLIC_KEY_PATH', storage_path('app/private/pubkey.pem')),
    ],

    // the settings read from the env until 2026-10, now in the settings table: their first values there (migrations
    // database/settings/2026_10_20_*), read here to work with a cached config. To remove once these migrations ran in
    // production, with the variables of the env.
    'legacy' => [
        'games_per_day' => env('KADO_GAMES_PER_DAY'),
        'runs_max_concurrency' => env('KADO_RUNS_MAX_CONCURRENCY'),
        'runs_open_minutes' => env('KADO_RUNS_OPEN_MINUTES'),
        'achievements_enabled' => env('KADO_ACHIEVEMENTS_ENABLED'),
        'game_builds_enabled' => env('KADO_GAME_BUILDS_ENABLED'),
        'theme_karbon_price' => env('KADO_THEME_KARBON_PRICE'),
        'replay_max_length' => env('KADO_REPLAY_MAX_LENGTH'),
        'require_rng_stir' => env('KADO_REQUIRE_RNG_STIR'),
        'require_input_phases' => env('KADO_REQUIRE_INPUT_PHASES'),
        'soft_bits' => env('KADO_ANTICHEAT_SOFT_BITS'),
        'ignored_bits' => env('KADO_ANTICHEAT_IGNORED_BITS'),
        'suspicion_enabled' => env('KADO_SUSPICION'),
        'suspicion_world_record' => env('KADO_SUSPICION_WORLD_RECORD'),
        'verifier_enabled' => env('KADO_REPLAY_VERIFIER'),
        'verifier_timeout' => env('KADO_REPLAY_VERIFIER_TIMEOUT'),
        'verifier_untrusted_games' => env('KADO_REPLAY_VERIFIER_UNTRUSTED_GAMES'),
        'analysis_enabled' => env('KADO_REPLAY_ANALYSIS'),
        'analysis_flag' => env('KADO_REPLAY_ANALYSIS_FLAG'),
        'analysis_sample_rate' => env('KADO_REPLAY_ANALYSIS_SAMPLE_RATE'),
    ],
];
