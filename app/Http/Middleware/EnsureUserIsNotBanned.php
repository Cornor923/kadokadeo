<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

/**
 * Logs out a banned user on their next API request: their session ends, their tokens are revoked and the front shows
 * the reason of the ban (`banned` in the response).
 */
class EnsureUserIsNotBanned
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user('sanctum');

        if ($user?->isBanned()) {
            $user->tokens()->delete();
            Auth::guard('web')->logout();
            if ($request->hasSession()) {
                $request->session()->invalidate();
                $request->session()->regenerateToken();
            }

            return response()->json([
                'message' => $user->banMessage(),
                'banned' => true,
            ], Response::HTTP_FORBIDDEN);
        }

        return $next($request);
    }
}
