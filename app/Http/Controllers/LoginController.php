<?php

namespace App\Http\Controllers;

use App\Http\Resources\UserResource;
use App\Models\User;
use App\Settings\ClanSettings;
use App\Settings\SiteSettings;
use Eternaltwin\Client\Auth as EtwinAuth;
use Eternaltwin\Client\HttpEtwinClient;
use Eternaltwin\OauthClient\RfcOauthClient;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;

class LoginController extends Controller implements HasMiddleware
{
    // the state of the OAuth login, kept by the browser that began it: a code sent to another browser (a link to the
    // callback with the code of someone else, to log the victim in their account) is refused
    public const OAUTH_STATE_COOKIE = 'kado_oauth_state';

    private const OAUTH_STATE_COOKIE_PATH = '/api/oauth';

    // minutes to log in on Eternaltwin
    private const OAUTH_STATE_MINUTES = 15;

    private readonly RfcOauthClient $oauthClient;

    private readonly HttpEtwinClient $etwinClient;

    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum', only: ['logout']),
            // each callback calls Eternaltwin twice
            new Middleware('throttle:10,1', only: ['loginCallback']),
        ];
    }

    public function __construct()
    {
        $this->etwinClient = new HttpEtwinClient(config('services.etwin.identityServerUri'));
        $this->oauthClient = new RfcOauthClient(
            config('services.etwin.eternaltwinUrl').'oauth/authorize',
            config('services.etwin.eternaltwinUrl').'oauth/token',
            url('/oauth/callback'),
            config('services.etwin.oauthId'),
            config('services.etwin.oauthSecret')
        );
    }

    // Send the user the the Eternal-twin connection form for sign in
    public function login(Request $request)
    {
        // "forum:write": the forum of Eternaltwin, as the player (App\Http\Controllers\Api\EtwinForumController)
        $scope = config('services.etwin.scope');
        $state = Str::random(40);

        try {
            $authorizationUri = $this->oauthClient->getAuthorizationUri($scope, $state);
        } catch (\Exception $e) {
            // TODO: Handle error properly, maybe redirect to an error page
            return $e->getMessage();
        }

        return redirect()->away($authorizationUri)->withCookie(cookie(
            self::OAUTH_STATE_COOKIE,
            $state,
            self::OAUTH_STATE_MINUTES,
            self::OAUTH_STATE_COOKIE_PATH,
            null,
            $request->isSecure(),
            true,
            false,
            'lax',
        ));
    }

    public function logout(Request $request)
    {
        // a page opened before the session cookies still sends its token: it goes with the logout (whether the request
        // was authenticated by it or by the session)
        if ($bearer = $request->bearerToken()) {
            Sanctum::personalAccessTokenModel()::findToken($bearer)?->delete();
        }
        Auth::guard('web')->logout();
        if ($request->hasSession()) {
            $request->session()->invalidate();
            $request->session()->regenerateToken();
        }

        return response()->noContent();
    }

    // Get the callback from Eternal-twin when connected successfully, then create the session: its cookie (HttpOnly) and
    // the one of « remember me » keep the player logged in, no token is given to the page
    public function loginCallback(Request $request)
    {
        $data = $request->validate([
            'code' => 'required|string',
            'state' => 'required|string',
        ]);
        $expectedState = $request->cookie(self::OAUTH_STATE_COOKIE);
        if (!is_string($expectedState) || !hash_equals($expectedState, $data['state'])) {
            return response()->json([
                'message' => 'La connexion a expiré ou a été commencée dans un autre navigateur. Reconnectez-vous.',
            ], 422)->withoutCookie(self::OAUTH_STATE_COOKIE, self::OAUTH_STATE_COOKIE_PATH);
        }

        $accessToken = $this->oauthClient->getAccessTokenSync($data['code']);
        $self = $this->etwinClient->getSelf(EtwinAuth::fromToken($accessToken->getAccessToken()));
        $user = $self->getUser();
        $userDisplayName = $user->getDisplayName()->getCurrent()->getValue();
        $userUuid = $user->getId();

        $attrs = [
            'etwin_id' => $userUuid->toString(),
            'display_name' => $userDisplayName->toString(),
            'last_seen_at' => now(),
            // kept to call the forum of Eternaltwin as the player, with what the player allowed
            'etwin_access_token' => $accessToken->getAccessToken(),
            'etwin_scopes' => $this->scopesOf($accessToken->getAccessToken()),
        ];

        // Check if the user already exists in the database
        $dbUser = User::where('etwin_id', $userUuid->toString())->first();
        if ($dbUser?->isBanned()) {
            return response()->json([
                'message' => $dbUser->banMessage(),
                'banned' => true,
            ], 403);
        }
        if ($dbUser) {
            $dbUser->fill($attrs);
        } else {
            $dbUser = new User($attrs);
            $dbUser->kado_games = app(SiteSettings::class)->games_per_day;
            $dbUser->clan_attack_games = app(ClanSettings::class)->attack_games_per_day;
        }
        $dbUser->save();
        Auth::login($dbUser, true);
        // (a new id for the session of a logged in player, and a new CSRF token: against the fixation of the session)
        if ($request->hasSession()) {
            $request->session()->regenerate();
        }

        return response()->json([
            'user' => UserResource::make($dbUser),
        ])->withoutCookie(self::OAUTH_STATE_COOKIE, self::OAUTH_STATE_COOKIE_PATH);
    }

    // what the token allows ({"base": true, "forum_read": true, "forum_write": true, ...}): the player may have allowed
    // less than asked (null: an Eternaltwin without scopes)
    private function scopesOf(string $accessToken): ?array
    {
        try {
            return Http::withToken($accessToken)
                ->acceptJson()
                ->timeout(10)
                ->get(rtrim(config('services.etwin.eternaltwinUrl'), '/').'/api/v1/auth/self')
                ->json('scopes');
        } catch (\Throwable) {
            return null;
        }
    }
}
