<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\Http;

// the forum of Eternaltwin (https://eternaltwin.org/docs/app/etwin-forum), called from here as the player with his access
// token of Eternaltwin (users.etwin_access_token, given at the login): Eternaltwin sends no CORS headers, its API can't
// be called from the browser. Only the requests of the forum the site uses go through, as they are.
class EtwinForumController extends Controller implements HasMiddleware
{
    private const REF = '[A-Za-z0-9_-]+';

    private const UUID = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';

    // the paths of /api/v1/forum the site uses, by method
    private const PATHS = [
        'GET' => ['sections', 'sections/'.self::REF, 'threads/'.self::REF, 'posts/'.self::UUID, 'posts/'.self::UUID.'/source'],
        'POST' => ['sections/'.self::REF, 'threads/'.self::REF, 'threads/'.self::REF.'/read', 'read_floor'],
        'PATCH' => ['posts/'.self::UUID],
    ];

    // what the writes may send (the bodies of https://eternaltwin.org/docs/app/etwin-forum)
    private const BODY_FIELDS = ['title', 'body', 'up_to_post', 'last_revision_id', 'content', 'comment'];

    // the refusals of Eternaltwin (its "error" is in English): what the player is told
    private const MESSAGES = [
        400 => 'Le message n\'a pas pu être lu par le forum (Marktwin invalide) ou cette section ne reçoit pas de sujets.',
        401 => 'Votre autorisation Eternaltwin n\'est plus valide : reconnectez-vous.',
        403 => 'Le forum d\'Eternaltwin a refusé cette action.',
        404 => 'Ce sujet ou cette section n\'existe pas.',
        409 => 'C\'est déjà fait : rechargez la page.',
        422 => 'La requête n\'est pas cohérente.',
    ];

    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum'),
            new Middleware('throttle:20,1', only: ['write']),
        ];
    }

    // what the player can do on the forum, and the category shown by the site
    public function status(Request $request)
    {
        $user = $request->user();
        $asksWrite = str_contains((string) config('services.etwin.scope'), 'forum:write');

        return ['data' => [
            'category' => config('services.etwin.forumCategory'),
            'can_write' => $user->canWriteEtwinForum(),
            // the site asks for the forum, the token of the player is older (or the player allowed less): logging in again
            // asks for it
            'needs_login' => $asksWrite && !$user->canWriteEtwinForum(),
        ]];
    }

    // GET /api/v1/config: the sizes of the pages of the forum
    public function config(Request $request)
    {
        return $this->forward($request, 'GET', 'config', []);
    }

    public function read(Request $request, string $path)
    {
        $this->assertPath('GET', $path);
        $query = array_filter([
            'offset' => $request->integer('offset', 0) ?: null,
            'limit' => $request->integer('limit') ?: null,
        ], fn ($value) => $value !== null);

        return $this->forward($request, 'GET', 'forum/'.$path, $query);
    }

    public function write(Request $request, string $path)
    {
        $method = $request->method();
        $this->assertPath($method, $path);
        if (!$request->user()->canWriteEtwinForum()) {
            return response()->json([
                'message' => 'Pour écrire sur le forum, reconnectez-vous et autorisez Kadokadéo à poster pour vous.',
                'needs_login' => true,
            ], 403);
        }

        return $this->forward($request, $method, 'forum/'.$path, (object) $request->only(self::BODY_FIELDS));
    }

    private function assertPath(string $method, string $path): void
    {
        foreach (self::PATHS[$method] ?? [] as $pattern) {
            if (preg_match('#^'.$pattern.'$#', $path)) {
                return;
            }
        }
        abort(404);
    }

    // the request sent to Eternaltwin as the player (with his token when he has one), its answer as it is: its "error"
    // is kept, the "message" shown to the player is added
    private function forward(Request $request, string $method, string $path, array|object $data)
    {
        $user = $request->user();
        $client = Http::baseUrl(rtrim(config('services.etwin.eternaltwinUrl'), '/').'/api/v1')
            ->acceptJson()
            ->asJson()
            ->timeout(15);
        if ($user->etwin_access_token) {
            $client = $client->withToken($user->etwin_access_token);
        }

        try {
            $response = $method === 'GET' ? $client->get($path, $data) : $client->send($method, $path, ['json' => $data]);
        } catch (ConnectionException) {
            return response()->json(['message' => 'Le forum d\'Eternaltwin ne répond pas, réessayez plus tard.'], 502);
        }

        $body = $response->json() ?? [];
        if ($response->failed()) {
            // a token Eternaltwin can't read any more: forgotten, the next login gives a new one
            if ($response->status() === 401) {
                $user->forceFill(['etwin_access_token' => null, 'etwin_scopes' => null])->save();
            }
            $body = [
                'error' => $body['error'] ?? null,
                'message' => self::MESSAGES[$response->status()] ?? 'Le forum d\'Eternaltwin a renvoyé une erreur.',
                'needs_login' => $response->status() === 401,
            ];
        }

        return response()->json($body, $response->status() === 401 ? 403 : $response->status());
    }
}
