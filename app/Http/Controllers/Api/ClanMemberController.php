<?php

namespace App\Http\Controllers\Api;

use App\Enums\ClanCombatRole;
use App\Enums\ClanRole;
use App\Http\Controllers\Controller;
use App\Http\Resources\UserLightResource;
use App\Models\Clan;
use App\Models\ClanApplication;
use App\Models\User;
use App\Services\ClanService;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Validation\Rule;

// joining (applications accepted by the leader or a right hand), leaving and managing the members of a clan
class ClanMemberController extends Controller implements HasMiddleware
{
    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum'),
            new Middleware('throttle:30,1', only: ['apply']),
        ];
    }

    public function __construct(private readonly ClanService $clanService) {}

    // the applications waiting for the decision of the leader or a right hand
    public function applications(Request $request, Clan $clan)
    {
        $this->clanService->assertManager($request->user(), $clan);

        return [
            'data' => $clan->applications()
                ->where('status', ClanApplication::PENDING)
                ->with('user')
                ->orderBy('created_at')
                ->get()
                ->map(fn (ClanApplication $application) => [
                    'id' => $application->id,
                    'user' => UserLightResource::make($application->user),
                    'message' => $application->message,
                    'created_at' => $application->created_at?->toIso8601String(),
                ]),
        ];
    }

    public function apply(Request $request, Clan $clan)
    {
        $validated = $request->validate(['message' => ['nullable', 'string', 'max:500']]);
        $application = $this->clanService->apply($request->user(), $clan, $validated['message'] ?? null);

        return response()->json(['data' => ['id' => $application->id]], 201);
    }

    public function cancel(Request $request, ClanApplication $application)
    {
        $this->clanService->cancelApplication($request->user(), $application);

        return response()->noContent();
    }

    public function accept(Request $request, ClanApplication $application)
    {
        $this->clanService->acceptApplication($request->user(), $application);

        return response()->noContent();
    }

    public function refuse(Request $request, ClanApplication $application)
    {
        $this->clanService->refuseApplication($request->user(), $application);

        return response()->noContent();
    }

    public function leave(Request $request)
    {
        $this->clanService->leave($request->user());

        return response()->noContent();
    }

    public function kick(Request $request, Clan $clan, User $user)
    {
        $this->clanService->kick($request->user(), $clan, $user);

        return response()->noContent();
    }

    public function promote(Request $request, Clan $clan, User $user)
    {
        $this->clanService->transferLeadership($request->user(), $clan, $user);

        return response()->noContent();
    }

    // "Bras droit" or member
    public function role(Request $request, Clan $clan, User $user)
    {
        $validated = $request->validate(['role' => ['required', Rule::in([ClanRole::RIGHT_HAND->value, ClanRole::MEMBER->value])]]);
        $this->clanService->setRole($request->user(), $clan, $user, ClanRole::from($validated['role']));

        return response()->noContent();
    }

    // "Attaquant", "Défenseur" or none (null)
    public function combatRole(Request $request, Clan $clan, User $user)
    {
        $validated = $request->validate(['combat_role' => ['present', 'nullable', Rule::enum(ClanCombatRole::class)]]);
        $role = $validated['combat_role'] !== null ? ClanCombatRole::from($validated['combat_role']) : null;
        $this->clanService->setCombatRole($request->user(), $clan, $user, $role);

        return response()->noContent();
    }

    // the status shown to the clan in the list of the members ("dispo le soir"...)
    public function status(Request $request, Clan $clan, User $user)
    {
        $validated = $request->validate(['status' => ['present', 'nullable', 'string', 'max:60']]);
        $this->clanService->setStatus($request->user(), $clan, $user, $validated['status']);

        return response()->noContent();
    }

    public function dissolve(Request $request, Clan $clan)
    {
        $this->clanService->dissolve($request->user(), $clan);

        return response()->noContent();
    }
}
