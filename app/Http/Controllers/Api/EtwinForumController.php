<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;

// the forum of the site is the forum of Eternaltwin, embedded (https://eternaltwin.org/docs/app/etwin-forum-embed): its
// script puts it in an iframe of Eternaltwin and asks the page for the access token of the player
// (users.etwin_access_token, given at the login), which it then sends to Eternaltwin itself. Nothing of the forum goes
// through this site any more.
class EtwinForumController extends Controller implements HasMiddleware
{
    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum'),
        ];
    }

    // where the forum is and what the player can do on it
    public function status(Request $request)
    {
        $user = $request->user();
        $asksWrite = str_contains((string) config('services.etwin.scope'), 'forum:write');

        return ['data' => [
            // the address the browser loads the forum from (the server reaches Eternaltwin at services.etwin.eternaltwinUrl)
            'url' => rtrim((string) config('services.etwin.publicUrl'), '/'),
            'group' => config('services.etwin.forumCategory'),
            'can_write' => $user->canWriteEtwinForum(),
            // the site asks for the forum, the token of the player is older (or the player allowed less): logging in again
            // asks for it
            'needs_login' => $asksWrite && !$user->canWriteEtwinForum(),
        ]];
    }

    // the access token of the player, for the forum to read and write as him; never kept by the browser or a cache
    public function token(Request $request)
    {
        $user = $request->user();
        if (!$user->canReadEtwinForum()) {
            return response()->json([
                'message' => 'Pour lire le forum en votre nom, reconnectez-vous et autorisez Kadokadéo à le lire pour vous.',
                'needs_login' => true,
            ], 403)->header('Cache-Control', 'no-store');
        }

        return response()
            ->json(['access_token' => $user->etwin_access_token])
            ->header('Cache-Control', 'no-store');
    }
}
