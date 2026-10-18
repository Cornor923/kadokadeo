<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Clan;
use App\Models\ClanAction;
use App\Models\ClanAttack;
use App\Models\Game;
use App\Services\ClanWarService;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;

// "Attaquer ce clan", "Améliorer", "Défendre", "Annuler": the run itself is played on the clan action page
// (ClanActionController). And "Déclarer la guerre" / "Faire la paix".
class ClanWarController extends Controller implements HasMiddleware
{
    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum'),
            new Middleware('throttle:30,1', only: ['attack', 'improve', 'defend', 'reserve', 'declareWar', 'endWar']),
        ];
    }

    public function __construct(private readonly ClanWarService $warService) {}

    public function attack(Request $request, Clan $clan)
    {
        $validated = $request->validate(['game_id' => ['required', 'integer', 'exists:games,id']]);
        $action = $this->warService->startAttack($request->user(), $clan, Game::query()->findOrFail($validated['game_id']));

        return $this->actionResponse($action);
    }

    // "Déclarer la guerre" / "Faire la paix" to the clan of the page (the leader and the right hands of another clan)
    public function declareWar(Request $request, Clan $clan)
    {
        $this->warService->declareWar($request->user(), $clan);

        return response()->noContent();
    }

    public function endWar(Request $request, Clan $clan)
    {
        $this->warService->endWar($request->user(), $clan);

        return response()->noContent();
    }

    public function improve(Request $request, ClanAttack $attack)
    {
        return $this->actionResponse($this->warService->startImprovement($request->user(), $attack));
    }

    public function defend(Request $request, ClanAttack $attack)
    {
        return $this->actionResponse($this->warService->startDefense($request->user(), $attack));
    }

    public function reserve(Request $request, ClanAttack $attack)
    {
        $this->warService->reserveDefense($request->user(), $attack);

        return response()->noContent();
    }

    public function cancel(Request $request, ClanAttack $attack)
    {
        $this->warService->cancelAttack($request->user(), $attack);

        return response()->noContent();
    }

    private function actionResponse(ClanAction $action)
    {
        return response()->json(['data' => ['id' => $action->id]], 201);
    }
}
