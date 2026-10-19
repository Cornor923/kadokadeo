<?php

namespace App\Http\Middleware;

use App\Settings\ClanSettings;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * The routes of the clans, refused while the clans are turned off in the admin (ClanSettings::$enabled). The admin
 * panel still manages them.
 */
class EnsureClansAreEnabled
{
    public function handle(Request $request, Closure $next): Response
    {
        abort_unless(app(ClanSettings::class)->enabled, Response::HTTP_FORBIDDEN, 'Les clans seront bientôt disponibles.');

        return $next($request);
    }
}
