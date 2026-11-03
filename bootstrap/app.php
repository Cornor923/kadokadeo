<?php

use App\Http\Controllers\LoginController;
use App\Http\Middleware\EnsureUserIsNotBanned;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Spatie\DiscordAlerts\Facades\DiscordAlert;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    // the SPA is authenticated by its session (Sanctum, statefulApi below): /api/broadcasting/auth, banned users refused
    // (api group)
    ->withBroadcasting(__DIR__.'/../routes/channels.php', ['prefix' => 'api', 'middleware' => ['api', 'auth:sanctum']])
    ->withMiddleware(function (Middleware $middleware): void {
        // the SPA and the games (same origin) are authenticated by the session cookie of the site (HttpOnly: no script
        // reads it) and protected by the CSRF token of the cookie XSRF-TOKEN; the requests of other origins need a token
        $middleware->statefulApi();
        $middleware->api(append: [
            EnsureUserIsNotBanned::class,
        ]);
        // set by the login page (web), read by the API at the end of the login: a random value, compared as it is
        $middleware->encryptCookies(except: [LoginController::OAUTH_STATE_COOKIE]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->dontReportDuplicates();
        if (config('discord-alerts.webhook_urls.default')) {
            $exceptions->report(function (Throwable $e) {
                $t = $e->getTrace()[0];
                $f = data_get($t, 'file', 'unknown file');
                $l = data_get($t, 'line', 'unknown line');
                $fu = data_get($t, 'function', 'unknown function');
                DiscordAlert::to('default')->message(sprintf("```%s\n%s:%s@%s```", $e->getMessage(), $f, $l, $fu));
            });
        }
    })->create();
