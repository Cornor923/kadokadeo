<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserLightResource;
use App\Models\Clan;
use App\Models\ClanGameTransfer;
use App\Models\User;
use App\Services\ClanGameService;
use App\Services\ClanService;
use App\Settings\ClanSettings;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;

// "Parties de clan": the paid games of the player (bought by packs with Kado points) and of his clan
class ClanGameController extends Controller implements HasMiddleware
{
    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum'),
            new Middleware('throttle:30,1', only: ['buy', 'donate', 'distribute']),
        ];
    }

    public function __construct(
        private readonly ClanService $clanService,
        private readonly ClanGameService $gameService,
    ) {}

    public function index(Request $request, ClanSettings $settings)
    {
        $user = $request->user()->fresh();
        $clan = $this->clanService->clanOf($user);

        return [
            'data' => [
                'packs' => collect($this->gameService->packs())->map(fn (int $price, int $count) => [
                    'count' => $count,
                    'price' => $price,
                    'unit_price' => intdiv($price, $count),
                ])->values(),
                'kado_points' => $user->kado_points,
                // the free attack and defense games left today
                'attack_games' => $user->clan_attack_games,
                'attack_games_per_day' => $settings->attack_games_per_day,
                'games' => $user->clan_games,
                'clan' => $clan ? [
                    'id' => $clan->id,
                    'games' => $clan->clan_games,
                    'can_distribute' => (bool) $this->clanService->roleOf($user, $clan)?->canManage(),
                    'transfers' => $clan->gameTransfers()->with('fromUser', 'toUser')->latest('id')->limit(20)->get()
                        ->map(fn (ClanGameTransfer $transfer) => [
                            'type' => $transfer->type,
                            'count' => $transfer->count,
                            'from' => $transfer->fromUser ? UserLightResource::make($transfer->fromUser) : null,
                            'to' => $transfer->toUser ? UserLightResource::make($transfer->toUser) : null,
                            'created_at' => $transfer->created_at?->toIso8601String(),
                        ]),
                ] : null,
            ],
        ];
    }

    public function buy(Request $request)
    {
        $validated = $request->validate(['count' => ['required', 'integer']]);
        $this->gameService->buy($request->user(), $validated['count']);

        return response()->noContent();
    }

    // games bought by the player, given to his clan
    public function donate(Request $request, Clan $clan)
    {
        $validated = $request->validate(['count' => ['required', 'integer', 'min:1']]);
        $this->gameService->donate($request->user(), $clan, $validated['count']);

        return response()->noContent();
    }

    // games of the clan, given to a member by the leader or a right hand
    public function distribute(Request $request, Clan $clan, User $user)
    {
        $validated = $request->validate(['count' => ['required', 'integer', 'min:1']]);
        $this->gameService->distribute($request->user(), $clan, $user, $validated['count']);

        return response()->noContent();
    }
}
