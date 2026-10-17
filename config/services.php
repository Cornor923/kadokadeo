<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'token' => env('POSTMARK_TOKEN'),
    ],

    'resend' => [
        'key' => env('RESEND_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'etwin' => [
        'identityServerUri' => env('ETERNALTWIN_URL', 'https://identity.eternaltwin.com/'),
        'eternaltwinUrl' => env('ETERNALTWIN_URL', 'https://eternaltwin.com/'),
        'oauthId' => env('ETERNALTWIN_CLIENT_ID', ''),
        'oauthSecret' => env('ETERNALTWIN_CLIENT_SECRET', ''),
        // the scope asked at the login: "forum:write" to post in the forum of Eternaltwin as the player (the app must be
        // allowed it on Eternaltwin, or the login is refused), "base" otherwise
        'scope' => env('ETERNALTWIN_SCOPE', 'base'),
        // the category of the forum of Eternaltwin shown in the "Forum" of the site (its sections)
        'forumCategory' => env('ETERNALTWIN_FORUM_CATEGORY', 'kadokadeo'),
    ],

];
