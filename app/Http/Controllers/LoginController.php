<?php

namespace App\Http\Controllers;

use App\Http\Resources\UserResource;
use App\Models\User;
use App\Settings\ClanSettings;
use Eternaltwin\Client\Auth as EtwinAuth;
use Eternaltwin\Client\HttpEtwinClient;
use Eternaltwin\OauthClient\RfcOauthClient;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Http;

class LoginController extends Controller implements HasMiddleware
{
    private readonly RfcOauthClient $oauthClient;

    private readonly HttpEtwinClient $etwinClient;

    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum', only: ['logout']),
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
    public function login()
    {
        // "forum:write": the forum of Eternaltwin, as the player (App\Http\Controllers\Api\EtwinForumController)
        $scope = config('services.etwin.scope');
        $state = 'kadokadeo';

        try {
            $authorizationUri = $this->oauthClient->getAuthorizationUri($scope, $state);
        } catch (\Exception $e) {
            // TODO: Handle error properly, maybe redirect to an error page
            return $e->getMessage();
        }

        return redirect()->away($authorizationUri);
    }

    public function logout(Request $request)
    {
        // $request->session()->invalidate();
        // $request->session()->regenerateToken();
        $request->user()->currentAccessToken()->delete();
    }

    // Get the callback from Eternal-twin when connected successfully, then create the session
    public function loginCallback(Request $request)
    {
        $data = $request->validate([
            'code' => 'required|string',
            // 'state' => 'required|string',
        ]);

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
            $dbUser->kado_games = config('kado.games_per_day');
            $dbUser->clan_attack_games = app(ClanSettings::class)->attack_games_per_day;
        }
        $dbUser->save();
        Auth::login($dbUser, true);

        $token = $dbUser->createToken('kadokadeo')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => UserResource::make($dbUser),
        ]);
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
