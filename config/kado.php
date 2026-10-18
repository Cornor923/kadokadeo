<?php

return [
    'games_per_day' => env('KADO_GAMES_PER_DAY', 100), // -1 for unlimited

    // a replay of a run outside the daily game must have its draws stirred by the frames and the inputs
    // (App\Support\ReplayHeader::FLAG_RNG_STIR), otherwise the run is flagged as cheated. To turn on once the pages
    // opened before the deployment of the games with the stir are gone (a day or two).
    'require_rng_stir' => env('KADO_REQUIRE_RNG_STIR', false),

    // ... and by the time of the inputs in their frame (replay version 4, App\Support\ReplayHeader::FLAG_INPUT_PHASES).
    // Same: to turn on a day or two after the deployment of the games that record it.
    'require_input_phases' => env('KADO_REQUIRE_INPUT_PHASES', false),

    'anticheat' => [
        // the bits of what the game detected during a run (App\Enums\AntiCheatBit) that don't mark it as cheated, but put
        // it in the queue of the suspicious runs (extensions can do it too: other display objects, functions of the
        // browser...). Default: 0x10 to 0x200. 0: any bit marks the run as cheated.
        'soft_bits' => (int) env('KADO_ANTICHEAT_SOFT_BITS', 0x3F0),
        // the bits that neither mark the run as cheated nor put it in the queue (they win over soft_bits): kept on the run
        // only. Default: 0xC0, the functions of the browser replaced and the inputs made by a script, raised by most of the
        // mobile browsers. 0: none.
        'ignored_bits' => (int) env('KADO_ANTICHEAT_IGNORED_BITS', 0xC0),
    ],

    // the queue of the suspicious runs of the admin (App\Services\SuspicionService): nothing is sanctioned, an admin decides
    'suspicion' => [
        'enabled' => (bool) env('KADO_SUSPICION', true),
        // a score above the record of the game (all the periods), once it has game_min_runs finished runs. A high score
        // alone is not looked at: too many legit runs in the queue
        'world_record' => (bool) env('KADO_SUSPICION_WORLD_RECORD', true),
        'game_min_runs' => 200,
        // the frames of the replay (32 by second) can't be more than the time of the run on the server
        'wall_clock_tolerance' => 0.02,
        'wall_clock_margin_seconds' => 5,
        // far fewer frames than the time of the run (the time on the intro and contract screens counts too: off)
        'slow_motion' => false,
        'slow_ratio' => 0.4,
        'slow_min_seconds' => 120,
    ],

    // the replays of the runs that count (personal best, contract, daily game) are played again on the server in a
    // headless Chrome to check their score (App\Jobs\VerifyRunReplay, on the queue): needs Node 22+ and Chrome
    'replay_verifier' => [
        'enabled' => env('KADO_REPLAY_VERIFIER', false),
        'node' => env('KADO_REPLAY_VERIFIER_NODE', 'node'),
        // path of Chrome / Chromium (default: looked for at the usual places)
        'browser' => env('KADO_REPLAY_VERIFIER_BROWSER'),
        'timeout' => (int) env('KADO_REPLAY_VERIFIER_TIMEOUT', 300),
        // games whose replay sometimes ends differently from the live game (determinism bugs, 2026-10): a different
        // score is reported, not sanctioned
        'untrusted_games' => explode(',', env('KADO_REPLAY_VERIFIER_UNTRUSTED_GAMES', '')),
    ],

    // the analyzers of the moves of a game (resources/js/replay-verifier/analyzers/<game_key>.mjs), run by the replay
    // verifier: their result is kept with the verification, and puts the run in the queue of the suspicious runs once
    // `flag` is on (calibrate the thresholds first: php artisan kado:replays:analyze <game>)
    'replay_analysis' => [
        'enabled' => (bool) env('KADO_REPLAY_ANALYSIS', true),
        'flag' => (bool) env('KADO_REPLAY_ANALYSIS_FLAG', false),
        // share of the runs not verified otherwise (not a best score, a contract, the daily game) verified anyway for
        // their analysis, for the games with an analyzer (0 to 1)
        'sample_rate' => (float) env('KADO_REPLAY_ANALYSIS_SAMPLE_RATE', 0),
        'queue' => env('KADO_REPLAY_ANALYSIS_QUEUE', 'default'),
        'games' => [
            // suspicious: the best move (resources/js/replay-verifier/analyzers/binary/solver.mjs) at least optimal_rate
            // of the time, over min_decisions moves; max_depth: turns of a sequence looked at (the "misses" of the game)
            'binary' => ['min_decisions' => 25, 'optimal_rate' => 0.85, 'max_depth' => 3],
            // the best move looking max_depth groups ahead (points certain from the board: the new balls are random), over
            // the 20 moves of a game (resources/js/replay-verifier/analyzers/kaskade2/solver.mjs)
            'kaskade2' => ['min_decisions' => 15, 'optimal_rate' => 0.9, 'max_depth' => 3],
        ],
    ],

    'runs' => [
        // A single user can run this amount of games in parallel.
        'max_concurrency' => env('KADO_RUNS_MAX_CONCURRENCY', 50),
    ],

    'poids_plume' => [
        'jackpot' => env('KADO_POIDS_PLUME_JACKPOT', 0),
    ],

    // the looks of the site (App\Http\Controllers\Api\ThemeController): "base" for everyone, the others bought once with
    // Kado points. Karbon: the second theme of KadoKado (its images were in dat.kadokado.com/gfx/gui/karbon)
    'themes' => [
        'base' => ['name' => 'KadoKado', 'price' => 0],
        'karbon' => ['name' => 'Karbon', 'price' => (int) env('KADO_THEME_KARBON_PRICE', 10000)],
    ],

    // tools to try the clans without other players (/clans/debug: fake attacks, defenses and mission steps, time going by,
    // end of the period). Never in production.
    'debug_tools' => (bool) env('KADO_DEBUG_TOOLS', false) && env('APP_ENV') !== 'production',

    // off: nothing is evaluated on runs / league changes and nothing is shown to players (the admin stays available)
    'achievements' => [
        'enabled' => (bool) env('KADO_ACHIEVEMENTS_ENABLED', false),
    ],

    // versions of the game bundles kept for their replays (written by resources/js/games/build-games.mjs)
    'game_builds' => [
        // off: runs remember no version and every replay is played by the current bundle (the production wipes
        // storage/ at each deploy: the archive is lost)
        'enabled' => (bool) env('KADO_GAME_BUILDS_ENABLED', false),
        'path' => env('KADO_GAME_BUILDS_PATH', storage_path('app/game-builds')),
    ],

    'security' => [
        'private_key_path' => env('KADO_RSA_PRIVATE_KEY_PATH', storage_path('app/private/privkey.pem')),
        'public_key_path' => env('KADO_RSA_PUBLIC_KEY_PATH', storage_path('app/private/pubkey.pem')),
    ],
];
