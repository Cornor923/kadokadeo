<?php

namespace App\Http\Controllers\Api;

use App\Enums\ClanActionType;
use App\Exceptions\ClanException;
use App\Http\Controllers\Controller;
use App\Models\ClanAction;
use App\Services\ClanRunService;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;

// the page where a clan run is played: what the player has to do
class ClanActionController extends Controller implements HasMiddleware
{
    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum'),
            new Middleware('throttle:30,1', only: ['again', 'cancel']),
        ];
    }

    // a clan run begun and never ended (the page closed during the run): "Annuler la partie"
    public function cancel(Request $request, ClanAction $action, ClanRunService $clanRunService)
    {
        $clanRunService->cancel($request->user(), $action);

        return response()->noContent();
    }

    // when a clan run ends: the next run on the page ("Rejouer") counts for the clan too while its target is open
    public function again(Request $request, ClanAction $action, ClanRunService $clanRunService)
    {
        abort_unless($action->user_id === $request->user()->id, 404);
        try {
            $next = $clanRunService->again($action);
        } catch (ClanException $e) {
            // a mission step no longer open: why, for the page (it sends the player back to the missions)
            return ['data' => null, 'closed' => $e->getMessage()];
        }

        return ['data' => $next ? ['id' => $next->id] : null, 'closed' => null];
    }

    public function show(Request $request, ClanAction $action, ClanRunService $clanRunService)
    {
        abort_unless($action->user_id === $request->user()->id, 404);
        $action->load('game', 'clan', 'defenderClan', 'attack.attackerClan', 'attack.attackerUser', 'missionStep.mission');

        return [
            'data' => [
                'id' => $action->id,
                'type' => $action->type->value,
                'type_label' => $action->type->label(),
                'game_id' => $action->game_id,
                'clan' => ['id' => $action->clan->id, 'name' => $action->clan->name],
                // a new run on an attack of the player: its score replaces the attack only if it is higher
                'is_improvement' => $action->type === ClanActionType::ATTACK && $action->clan_attack_id !== null,
                // the runs of the missions are free
                'is_free' => $action->type === ClanActionType::MISSION,
                // its target over (a mission step completed, an attack ended...): playing there would be a normal run
                'is_open' => $clanRunService->isOpen($action),
                'result' => $action->result,
                'target' => match ($action->type) {
                    ClanActionType::ATTACK => [
                        'clan' => ['id' => $action->defenderClan->id, 'name' => $action->defenderClan->name],
                        'score' => $action->attack?->score,
                    ],
                    ClanActionType::DEFENSE => [
                        'clan' => ['id' => $action->attack->attackerClan->id, 'name' => $action->attack->attackerClan->name],
                        'attacker' => $action->attack->attackerUser->display_name,
                        'score' => $action->attack->score,
                    ],
                    ClanActionType::MISSION => [
                        'mission' => $action->missionStep->mission->number,
                        'score' => $action->missionStep->target_score,
                    ],
                },
            ],
        ];
    }
}
