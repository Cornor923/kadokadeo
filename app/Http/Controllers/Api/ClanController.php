<?php

namespace App\Http\Controllers\Api;

use App\Enums\ClanActionType;
use App\Enums\ClanAttackStatus;
use App\Enums\ClanBonusType;
use App\Enums\ClanCombatRole;
use App\Enums\ClanRole;
use App\Http\Controllers\Controller;
use App\Http\Resources\ClanAttackResource;
use App\Http\Resources\ClanHistoryResource;
use App\Http\Resources\ClanListResource;
use App\Http\Resources\UserLightResource;
use App\Models\Clan;
use App\Models\ClanAction;
use App\Models\ClanApplication;
use App\Models\ClanAttack;
use App\Models\ClanMember;
use App\Models\ClanMemberStat;
use App\Models\ClanMission;
use App\Models\ClanPeriodScore;
use App\Models\ClanWar;
use App\Rules\ClanName;
use App\Services\ClanMissionService;
use App\Services\ClanRunService;
use App\Services\ClanService;
use App\Services\ClanWarService;
use App\Settings\ClanSettings;
use App\Support\ClanMarkdown;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Validation\Rule;

class ClanController extends Controller implements HasMiddleware
{
    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum'),
        ];
    }

    public function __construct(
        private readonly ClanService $clanService,
        private readonly ClanWarService $warService,
    ) {}

    // the ranking of the clans of the current period ("Classement")
    public function index(Request $request)
    {
        $validated = $request->validate([
            'ranking' => ['sometimes', Rule::in(['war', 'missions'])],
            'q' => ['sometimes', 'nullable', 'string', 'max:32'],
        ]);
        $period = $this->clanService->currentPeriod();
        abort_unless($period, 404, 'Aucune période en cours.');
        $this->warService->resolveExpired();

        $ranking = $validated['ranking'] ?? 'war';
        $query = $this->clanService->rankingQuery($period, $ranking)->withCount('members');
        if (!empty($validated['q'])) {
            $query->where('clans.name', 'like', '%'.$validated['q'].'%');
        }

        $clans = $query->paginate(50);
        // the missions ranking: the steps done of the mission in progress of each clan
        $missions = $ranking === 'missions'
            ? ClanMission::query()
                ->where('period_id', $period->id)
                ->whereIn('clan_id', $clans->getCollection()->pluck('id'))
                ->where('status', ClanMission::ACTIVE)
                ->where('expires_at', '>', now())
                ->withCount(['steps', 'steps as steps_done_count' => fn ($q) => $q->where(fn ($q) => $q->whereNotNull('completed_at')->orWhere('skipped', true))])
                ->get()
                ->keyBy('clan_id')
            : collect();
        $clans->getCollection()->each(function (Clan $clan, int $index) use ($clans, $validated, $period, $ranking, $missions) {
            $mission = $missions->get($clan->id);
            $clan->mission = $mission ? ['number' => $mission->number, 'steps' => $mission->steps_count, 'steps_done' => $mission->steps_done_count] : null;
            // in a search, the position in the whole ranking
            $clan->rank = empty($validated['q'])
                ? ($clans->currentPage() - 1) * $clans->perPage() + $index + 1
                : $this->clanService->rankOf($clan, $period, $ranking);
        });

        return ClanListResource::collection($clans)->additional(['tournament' => $this->clanService->tournamentInfo()]);
    }

    // what the menus need: the period of the tournament, the clan of the player, the top 3 of the wars and of the missions
    public function overview(Request $request)
    {
        $user = $request->user();
        $period = $this->clanService->currentPeriod();
        $clan = $this->clanService->clanOf($user);
        $top = fn (string $ranking) => $period
            ? $this->clanService->rankingQuery($period, $ranking)->limit(3)->get()->each(fn ($c, $i) => $c->rank = $i + 1)
            : collect();

        return [
            'data' => [
                'tournament' => $this->clanService->tournamentInfo(),
                'clan' => $clan ? [
                    'id' => $clan->id,
                    'name' => $clan->name,
                    'is_leader' => $clan->leader_id === $user->id,
                    'can_manage' => (bool) $this->clanService->roleOf($user, $clan)?->canManage(),
                ] : null,
                'applications' => ClanApplication::query()
                    ->where('user_id', $user->id)
                    ->where('status', ClanApplication::PENDING)
                    ->with('clan:id,name')
                    ->get()
                    ->map(fn (ClanApplication $a) => ['id' => $a->id, 'clan' => ['id' => $a->clan->id, 'name' => $a->clan->name]]),
                'top' => ClanListResource::collection($top('war')),
                'top_missions' => ClanListResource::collection($top('missions')),
                // the tools of /clans/debug (kado.debug_tools)
                'debug' => (bool) config('kado.debug_tools'),
                // the rules of the clans (App\Settings\ClanSettings), for the help page and the clan pages
                'rules' => $this->rules(),
            ],
        ];
    }

    public function store(Request $request)
    {
        $request->merge(['name' => ClanName::normalize($request->input('name'))]);
        $validated = $request->validate([
            'name' => ['required', 'string', 'min:3', 'max:32', new ClanName()],
            'description' => ['nullable', 'string', 'max:5000'],
        ], [
            'name.min' => 'Le nom du clan doit faire au moins 3 caractères.',
            'name.max' => 'Le nom du clan doit faire au plus 32 caractères.',
        ]);

        $clan = $this->clanService->create($request->user(), $validated['name'], $validated['description'] ?? null);

        return response()->json(['data' => ['id' => $clan->id]], 201);
    }

    // "Présentation"
    public function show(Request $request, Clan $clan)
    {
        $user = $request->user();
        $period = $this->clanService->currentPeriod();
        $this->warService->resolveExpired();
        $clan->load('leader')->loadCount('members');

        $score = $period ? ClanPeriodScore::query()->where('clan_id', $clan->id)->where('period_id', $period->id)->first() : null;
        $myClan = $this->clanService->clanOf($user);
        $isMember = $myClan?->id === $clan->id;
        $role = $isMember ? $this->clanService->roleOf($user, $clan) : null;
        $attackBlocked = $this->attackBlockedReason($user, $myClan, $clan, $period);
        // another clan: the leader and the right hands of the clan of the player declare the war to it
        $canDeclareWar = $myClan !== null && !$isMember && (bool) $this->clanService->roleOf($user, $myClan)?->canManage();

        return [
            'data' => [
                'id' => $clan->id,
                'name' => $clan->name,
                'description' => $clan->description,
                'description_html' => ClanMarkdown::toHtml($clan->description),
                'is_recruiting' => $clan->is_recruiting,
                'created_at' => $clan->created_at?->toIso8601String(),
                'leader' => $clan->leader ? UserLightResource::make($clan->leader) : null,
                'members_count' => $clan->members_count,
                'max_members' => app(ClanSettings::class)->max_members,
                // the paid clan games given by the members, to distribute ("coffre" of the clan)
                'clan_games' => $isMember ? $clan->clan_games : null,
                'stats' => [
                    'war_rank' => $period ? $this->clanService->rankOf($clan, $period) : null,
                    'war_score' => $score?->war_score ?? 0,
                    'mission_rank' => $period ? $this->clanService->rankOf($clan, $period, 'missions') : null,
                    'mission_score' => $score?->mission_score ?? 0,
                    'attacks_won' => $score?->attacks_won ?? 0,
                    'defenses_won' => $score?->defenses_won ?? 0,
                ],
                // "Période 191 : TOP 4 au classement des clans"
                'history' => ClanPeriodScore::query()
                    ->where('clan_id', $clan->id)
                    ->whereNotNull('closed_at')
                    ->orderByDesc('period_id')
                    ->limit(20)
                    ->get(['period_id', 'war_rank', 'mission_rank', 'war_score', 'mission_score', 'reward']),
                'viewer' => [
                    'is_member' => $isMember,
                    'is_leader' => $clan->leader_id === $user->id,
                    // the leader and the right hands manage the clan
                    'can_manage' => (bool) $role?->canManage(),
                    'role' => $role?->value,
                    'combat_role' => $isMember ? $this->clanService->combatRoleOf($user, $clan)?->value : null,
                    // accepted during this period: he can't leave the clan before the next one
                    'is_new_member' => $isMember && $this->clanService->isNewMember($user, $clan),
                    'has_clan' => $myClan !== null,
                    'application_id' => ClanApplication::query()
                        ->where('clan_id', $clan->id)
                        ->where('user_id', $user->id)
                        ->where('status', ClanApplication::PENDING)
                        ->value('id'),
                    'attack_blocked' => $attackBlocked,
                    'can_declare_war' => $canDeclareWar,
                    // the clan of the player declared the war to this one
                    'at_war' => $myClan !== null && !$isMember
                        && ClanWar::query()->where('clan_id', $myClan->id)->where('target_clan_id', $clan->id)->exists(),
                    // his clan runs begun and never ended, to cancel them
                    'unfinished_actions' => $isMember ? $this->unfinishedActions($user) : [],
                    // the points his clan would win if the attack is not repelled
                    'attack_points' => $attackBlocked === null
                        ? $this->clanService->attackPoints($this->clanService->warScore($myClan, $period), $this->clanService->warScore($clan, $period))
                        : null,
                ],
            ],
            'tournament' => $this->clanService->tournamentInfo(),
        ];
    }

    public function update(Request $request, Clan $clan)
    {
        $this->clanService->assertManager($request->user(), $clan);
        $validated = $request->validate([
            'description' => ['sometimes', 'nullable', 'string', 'max:5000'],
            'is_recruiting' => ['sometimes', 'boolean'],
        ]);
        $clan->update($validated);

        return response()->noContent();
    }

    // "Membres": the ranking of the members of the clan during the period: 1 point by mission step, the points of their
    // successful attacks and defenses
    public function members(Request $request, Clan $clan)
    {
        $period = $this->clanService->currentPeriod();
        $stats = $period
            ? ClanMemberStat::query()->where('clan_id', $clan->id)->where('period_id', $period->id)->get()->keyBy('user_id')
            : collect();

        // the statuses are seen by the clan only: its own, or anyone's for the leader and the right hands
        $viewer = $request->user();
        $viewerRole = $this->clanService->roleOf($viewer, $clan);

        $members = ClanMember::query()
            ->where('clan_id', $clan->id)
            ->with('user')
            ->orderBy('created_at')
            ->get()
            ->map(function (ClanMember $member) use ($clan, $stats, $period, $viewer, $viewerRole) {
                $stat = $stats->get($member->user_id);
                $isLeader = $clan->leader_id === $member->user_id;

                return [
                    'user' => UserLightResource::make($member->user),
                    'is_leader' => $isLeader,
                    'role' => $isLeader ? ClanRole::LEADER->value : $member->role->value,
                    'combat_role' => $member->combat_role?->value,
                    // the seat was chosen during this period: it can't change before the next one
                    'combat_role_locked' => $period !== null && $member->combat_role_period_id === $period->id,
                    'joined_at' => $member->created_at?->toIso8601String(),
                    // accepted during this period: can't be excluded before the next one
                    'is_new' => $period !== null && $member->joined_period_id === $period->id,
                    'points' => ($stat?->mission_steps ?? 0) + ($stat?->performance ?? 0),
                    'attacks' => $stat?->attacks ?? 0,
                    'attacks_won' => $stat?->attacks_won ?? 0,
                    'defenses' => $stat?->defenses ?? 0,
                    'defenses_won' => $stat?->defenses_won ?? 0,
                    'mission_steps' => $stat?->mission_steps ?? 0,
                    'performance' => $stat?->performance ?? 0,
                    ...($viewerRole ? [
                        'status' => $member->status,
                        'can_edit_status' => $member->user_id === $viewer->id || $viewerRole->canManage(),
                    ] : []),
                ];
            })
            ->sortByDesc('points')
            ->values();

        return [
            'data' => $members,
            // the seats of "Attaquant" and "Défenseur" of the clan
            'seats' => collect(ClanCombatRole::cases())->mapWithKeys(fn (ClanCombatRole $role) => [
                $role->value => ['label' => $role->getLabel(), 'description' => $role->description(), 'count' => $this->clanService->combatSeats($clan, $role)],
            ]),
        ];
    }

    // "Statut": the attacks launched by the clan and the attacks against it still waiting for a defense
    public function status(Request $request, Clan $clan)
    {
        $this->warService->resolveExpired();
        $base = fn () => ClanAttack::query()
            ->with(['game', 'attackerUser', 'attackerClan', 'defenderClan', 'defenderUser', 'reservedBy'])
            ->active()
            ->orderBy('expires_at');

        return [
            'data' => [
                'launched' => ClanAttackResource::collection($base()->where('attacker_clan_id', $clan->id)->get()),
                'received' => ClanAttackResource::collection($base()->where('defender_clan_id', $clan->id)->get()),
                // the wars declared by the clan and against it: the targets of its members, its enemies
                'wars' => $this->warService->warsOf($clan)->map(fn (ClanWar $war) => [
                    'id' => $war->id,
                    'clan' => $war->clan->only(['id', 'name']),
                    'target' => $war->targetClan->only(['id', 'name']),
                    'declared_at' => $war->created_at->toIso8601String(),
                ]),
            ],
            'tournament' => $this->clanService->tournamentInfo(),
        ];
    }

    // "Historique": the finished attacks (A) and defenses (D) of the clan, the newest first (App\Http\Resources\ClanHistoryResource)
    public function history(Request $request, Clan $clan)
    {
        $this->warService->resolveExpired();
        $attacks = ClanAttack::query()
            ->with(['game', 'attackerUser', 'attackerClan', 'defenderClan', 'defenderUser', 'defenseRun'])
            ->whereIn('status', [ClanAttackStatus::WON, ClanAttackStatus::REPELLED])
            ->where(fn ($query) => $query->where('attacker_clan_id', $clan->id)->orWhere('defender_clan_id', $clan->id))
            ->orderByDesc('resolved_at')
            ->orderByDesc('id')
            ->paginate(50);

        return ClanHistoryResource::collection($attacks);
    }

    private function unfinishedActions($user): array
    {
        return app(ClanRunService::class)->unfinishedActions($user)->map(function (ClanAction $action) {
            $isImprovement = $action->type === ClanActionType::ATTACK && $action->clan_attack_id !== null;

            return [
                'id' => $action->id,
                'type' => $action->type->value,
                'label' => match (true) {
                    $isImprovement => 'Amélioration en cours…',
                    $action->type === ClanActionType::ATTACK => 'Attaque en cours…',
                    $action->type === ClanActionType::DEFENSE => 'Défense en cours…',
                    default => 'Étape de mission en cours…',
                },
                'game' => ['id' => $action->game->id, 'name' => $action->game->name],
                'target' => match ($action->type) {
                    ClanActionType::ATTACK => $action->defenderClan?->name,
                    ClanActionType::DEFENSE => $action->attack?->attackerClan?->name,
                    ClanActionType::MISSION => 'Mission '.$action->missionStep?->mission?->number,
                },
                // a new attack blocks the next attacks and the defenses
                'blocks' => $action->type === ClanActionType::ATTACK && !$isImprovement,
                'started_at' => $action->created_at->toIso8601String(),
            ];
        })->all();
    }

    private function rules(): array
    {
        $settings = app(ClanSettings::class);
        $missionService = app(ClanMissionService::class);
        // [last rank => points] as {from, to, points}
        $ranges = function (array $rewards) {
            $from = 1;
            $ranges = [];
            foreach ($rewards as $lastRank => $points) {
                $ranges[] = ['from' => $from, 'to' => $lastRank, 'points' => $points];
                $from = $lastRank + 1;
            }

            return $ranges;
        };

        return [
            'max_members' => $settings->max_members,
            // Kado points
            'creation_price' => $settings->creation_price,
            'application_price' => $settings->application_price,
            'attack_games_per_day' => $settings->attack_games_per_day,
            'attack_hours' => $settings->attack_hours,
            'attack_max_points' => $settings->attack_max_points,
            // one point less by this many points the attacked clan has below the attacker
            'attack_points_palier' => (int) max(1, $settings->protection_range / max(1, $settings->attack_max_points)),
            'protection_range' => $settings->protection_range,
            // the share of the members (%)
            'attacker_seats' => (int) round($settings->attacker_seats_share * 100),
            'defender_seats' => (int) round($settings->defender_seats_share * 100),
            'mission_hours' => $settings->mission_hours,
            'mission_more_time_hours' => $settings->mission_more_time_hours,
            // the steps of the first mission of a lone player, of a full clan
            'mission_steps_alone' => $missionService->stepsCount(1, 1),
            'mission_steps_full' => $missionService->stepsCount($settings->max_members, 1),
            'mission_points_first' => $settings->mission_points_first,
            'mission_points_every' => $settings->mission_points_every,
            'mission_points_min' => $settings->mission_points_min,
            // %
            'bonus_chance' => round($settings->bonus_chance * 100, 1),
            'bonuses' => collect(ClanBonusType::cases())->map(fn (ClanBonusType $type) => [
                'type' => $type->value,
                'label' => $type->getLabel(),
                'description' => $type->description(),
                'icon' => $type->icon(),
            ]),
            'game_packs' => collect($settings->gamePacks())->map(fn (int $price, int $count) => ['count' => $count, 'price' => $price])->values(),
            'rewards' => [
                'war' => $ranges($settings->rewards('war')),
                'missions' => $ranges($settings->rewards('missions')),
            ],
        ];
    }

    private function attackBlockedReason($user, ?Clan $myClan, Clan $clan, $period): ?string
    {
        if (!$myClan) {
            return 'Vous devez faire partie d\'un clan pour attaquer.';
        }
        if ($myClan->id === $clan->id) {
            return 'Vous ne pouvez pas attaquer votre propre clan.';
        }
        if (!$period) {
            return 'Aucune période en cours.';
        }
        $attackerScore = $this->clanService->warScore($myClan, $period);
        $defenderScore = $this->clanService->warScore($clan, $period);
        if ($this->clanService->isProtected($attackerScore, $defenderScore)) {
            return 'Ce clan est protégé de vos attaques : son score est trop éloigné du vôtre.';
        }

        return null;
    }
}
