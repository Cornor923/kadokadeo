<?php

namespace App\Http\Middleware;

use App\Services\VisitService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Notes a logged in player once a day by session (App\Services\VisitService), after the response: the first API request
 * of the day writes a row, the next ones only read the session. Without a session (Bearer tokens) nothing.
 */
class RecordVisit
{
    public const SESSION_KEY = 'visit_day';

    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->hasSession() ? $request->user('sanctum') : null;
        $today = today()->toDateString();

        if ($user && $request->session()->get(self::SESSION_KEY) !== $today) {
            $request->session()->put(self::SESSION_KEY, $today);
            defer(fn () => rescue(fn () => app(VisitService::class)->record($user, $request)));
        }

        return $next($request);
    }
}
