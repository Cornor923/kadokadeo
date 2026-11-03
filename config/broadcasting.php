<?php

// the realtime of the site (App\Support\Realtime, channels in routes/channels.php): the events are sent at once to
// Reverb (started by kado:worker), never queued
return [

    // "reverb", or "log" / "null": no realtime, the front polls as before
    'default' => env('BROADCAST_CONNECTION', 'null'),

    'connections' => [

        'reverb' => [
            'driver' => 'reverb',
            'key' => env('REVERB_APP_KEY'),
            'secret' => env('REVERB_APP_SECRET'),
            'app_id' => env('REVERB_APP_ID'),
            // where this server sends the events (Reverb on the same machine: the port where it listens, WS_PORT given by
            // Katal, the hosting of Eternaltwin)
            'options' => [
                'host' => env('REVERB_HOST'),
                'port' => env('WS_PORT', env('REVERB_PORT', 443)),
                'scheme' => env('REVERB_SCHEME', 'https'),
                'useTLS' => env('REVERB_SCHEME', 'https') === 'https',
            ],
            // a Reverb that does not answer must not hold the request of a player
            'client_options' => [
                'connect_timeout' => 1,
                'timeout' => 2,
            ],
            // where the browsers connect (window.Kado.reverb): by default the host and the port of the page (443), the web
            // server sending /app and /apps to Reverb
            'client' => [
                'host' => env('REVERB_PUBLIC_HOST'),
                'port' => env('REVERB_PUBLIC_PORT'),
                'scheme' => env('REVERB_PUBLIC_SCHEME'),
            ],
        ],

        'log' => [
            'driver' => 'log',
        ],

        'null' => [
            'driver' => 'null',
        ],

    ],

];
