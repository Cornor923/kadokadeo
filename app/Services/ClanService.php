<?php

namespace App\Services;

use App\Enums\ClanBonusType;
use App\Enums\ClanCombatRole;
use App\Enums\ClanRole;
use App\Events\ClanUpdated;
use App\Exceptions\ClanException;
use App\Models\Clan;
use App\Models\ClanAction;
use App\Models\ClanApplication;
use App\Models\ClanBonus;
use App\Models\ClanMember;
use App\Models\ClanMemberStat;
use App\Models\ClanPeriodScore;
use App\Models\Period;
use App\Models\User;
use App\Rules\ClanName;
use App\Settings\ClanSettings;
use App\Support\Realtime;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

// the clans: groups of 1 to 50 players, led by a leader (a single one) helped by right hands (ClanRole). The tournament
// lasts a period (14 days): during all of it the clans attack each other and complete missions, then the scores, the
// missions and the options start again from 0 on the first day of the next period (the clans and their members stay).
class ClanService
{
    public function __construct(private readonly NotificationService $notifications) {}

    public function currentPeriod(): ?Period
    {
        return Period::current()->first();
    }

    public function tournamentInfo(): ?array
    {
        $period = $this->currentPeriod();
        if (!$period) {
            return null;
        }

        return [
            'period_id' => $period->id,
            'starts_at' => $period->start_at->toIso8601String(),
            'ends_at' => $period->end_at->toIso8601String(),
        ];
    }

    public function assertPeriod(): Period
    {
        return $this->currentPeriod() ?? throw new ClanException('Aucune période en cours.');
    }

    public function clanOf(User $user): ?Clan
    {
        return $user->clanMember()->first()?->clan;
    }

    public function isMember(User $user, Clan $clan): bool
    {
        return ClanMember::query()->where('clan_id', $clan->id)->where('user_id', $user->id)->exists();
    }

    public function assertMember(User $user, Clan $clan): void
    {
        if (!$this->isMember($user, $clan)) {
            throw new ClanException('Vous ne faites pas partie de ce clan.');
        }
    }

    // none outside the clan, even for a leader_id left on it
    public function roleOf(User $user, Clan $clan): ?ClanRole
    {
        $member = ClanMember::query()->where('clan_id', $clan->id)->where('user_id', $user->id)->first();
        if (!$member) {
            return null;
        }

        return $clan->leader_id === $user->id ? ClanRole::LEADER : $member->role;
    }

    // what only the leader can do: disband the clan, give the leadership
    public function assertLeader(User $user, Clan $clan): void
    {
        if ($clan->leader_id !== $user->id || !$this->isMember($user, $clan)) {
            throw new ClanException('Seul le chef de clan peut faire ça.');
        }
    }

    // everything else of the management of the clan: the leader and the right hands
    public function assertManager(User $user, Clan $clan): void
    {
        if (!$this->roleOf($user, $clan)?->canManage()) {
            throw new ClanException('Seuls le chef de clan et ses bras droits peuvent faire ça.');
        }
    }

    public function combatRoleOf(User $user, Clan $clan): ?ClanCombatRole
    {
        return ClanMember::query()->where('clan_id', $clan->id)->where('user_id', $user->id)->first()?->combat_role;
    }

    // the seats of a combat role: a share of the members (App\Settings\ClanSettings), at least 1
    public function combatSeats(Clan $clan, ClanCombatRole $role): int
    {
        $settings = app(ClanSettings::class);
        $share = $role === ClanCombatRole::ATTACKER ? $settings->attacker_seats_share : $settings->defender_seats_share;

        return max(1, (int) floor($clan->members()->count() * $share));
    }

    // ---------------------------------------------------------------- membership

    // a clan costs ClanSettings::$creation_price Kado points; the applications of its leader are cancelled and paid back
    public function create(User $user, string $name, ?string $description): Clan
    {
        return DB::transaction(function () use ($user, $name, $description) {
            // the player locked: one payment at a time
            $user = User::query()->lockForUpdate()->findOrFail($user->id);
            if ($this->clanOf($user)) {
                throw new ClanException('Vous faites déjà partie d\'un clan.');
            }
            $price = app(ClanSettings::class)->creation_price;
            if ($user->kado_points < $price) {
                throw new ClanException('Il vous faut '.number_format($price, 0, ',', '.').' points Kado pour créer un clan.');
            }

            $clan = $this->createClanRow([
                'name' => $name,
                'description' => $description,
                'leader_id' => $user->id,
            ]);
            $clan->members()->create(['user_id' => $user->id]);
            $this->spend($user, $price, 'clan creation', Clan::class, $clan->id);
            $this->closeApplications(ClanApplication::query()->where('user_id', $user->id), ClanApplication::CANCELLED);

            return $clan;
        });
    }

    // the name is unique whatever the case (clans_name_lower_unique): of two clans created together with the same name,
    // one gets the error of App\Rules\ClanName
    private function createClanRow(array $attributes): Clan
    {
        try {
            // (a savepoint: PostgreSQL refuses anything else in a transaction after the error)
            return DB::transaction(fn () => Clan::query()->create($attributes));
        } catch (UniqueConstraintViolationException) {
            throw ValidationException::withMessages(['name' => ClanName::TAKEN]);
        }
    }

    // an application costs ClanSettings::$application_price Kado points; several clans can be asked at once, each once
    public function apply(User $user, Clan $clan, ?string $message): ClanApplication
    {
        return DB::transaction(function () use ($user, $clan, $message) {
            // the player locked: the clicks sent together wait for each other, and the next ones find the application
            $user = User::query()->lockForUpdate()->findOrFail($user->id);
            if ($this->clanOf($user)) {
                throw new ClanException('Vous faites déjà partie d\'un clan.');
            }
            if (!$clan->is_recruiting) {
                throw new ClanException('Ce clan ne recrute pas pour le moment.');
            }
            if ($clan->members()->count() >= app(ClanSettings::class)->max_members) {
                throw new ClanException('Ce clan est complet.');
            }
            $pending = ClanApplication::query()
                ->where('clan_id', $clan->id)
                ->where('user_id', $user->id)
                ->where('status', ClanApplication::PENDING)
                ->exists();
            if ($pending) {
                throw new ClanException('Vous avez déjà envoyé votre candidature à ce clan.');
            }
            $price = app(ClanSettings::class)->application_price;
            if ($user->kado_points < $price) {
                throw new ClanException('Il vous faut '.number_format($price, 0, ',', '.').' points Kado pour envoyer une candidature.');
            }

            $application = $clan->applications()->create([
                'user_id' => $user->id,
                'message' => $message,
                'status' => ClanApplication::PENDING,
                'cost' => $price,
            ]);
            $this->spend($user, $price, 'clan application', ClanApplication::class, $application->id);
            // (sent once committed)
            $this->notifications->clanApplied($application);
            Realtime::send(new ClanUpdated($clan->id, [ClanUpdated::MEMBERS]));

            return $application;
        });
    }

    // withdrawn by the player: paid back
    public function cancelApplication(User $user, ClanApplication $application): void
    {
        DB::transaction(function () use ($user, $application) {
            $application = ClanApplication::query()->lockForUpdate()->findOrFail($application->id);
            if ($application->user_id !== $user->id || $application->status !== ClanApplication::PENDING) {
                throw new ClanException('Cette candidature ne peut pas être annulée.');
            }

            $this->refund($application);
            $this->notifications->clanApplicationClosed($application);
            $application->delete();
            Realtime::send(new ClanUpdated($application->clan_id, [ClanUpdated::MEMBERS]));
        });
    }

    // the player joins the clan: his other applications are cancelled and paid back
    public function acceptApplication(User $manager, ClanApplication $application): void
    {
        $clan = $application->clan;
        $this->assertManager($manager, $clan);

        $alreadyInClan = DB::transaction(function () use ($clan, $application, $manager) {
            // the clan is locked (PostgreSQL does not lock an aggregate): one acceptation at a time; then the player: two
            // clans accepting him together
            Clan::query()->lockForUpdate()->find($clan->id);
            User::query()->lockForUpdate()->find($application->user_id);
            $application = ClanApplication::query()->lockForUpdate()->findOrFail($application->id);
            if ($application->status !== ClanApplication::PENDING) {
                throw new ClanException('Cette candidature a déjà été traitée.');
            }
            if ($clan->members()->count() >= app(ClanSettings::class)->max_members) {
                throw new ClanException('Ce clan est complet.');
            }
            if (ClanMember::query()->where('user_id', $application->user_id)->exists()) {
                $this->closeApplication($application, ClanApplication::REFUSED);

                return true;
            }

            // he can't leave nor be excluded during this period
            $clan->members()->create(['user_id' => $application->user_id, 'joined_period_id' => $this->currentPeriod()?->id]);
            $application->update(['status' => ClanApplication::ACCEPTED]);
            $this->notifications->clanApplicationClosed($application);
            $this->notifications->clanAccepted($application, $manager);
            $this->closeApplications(ClanApplication::query()->where('user_id', $application->user_id), ClanApplication::CANCELLED);
            Realtime::send(new ClanUpdated($clan->id, [ClanUpdated::MEMBERS]));

            return false;
        });

        if ($alreadyInClan) {
            throw new ClanException('Ce joueur fait déjà partie d\'un clan.');
        }
    }

    // paid back
    public function refuseApplication(User $manager, ClanApplication $application): void
    {
        $this->assertManager($manager, $application->clan);

        DB::transaction(function () use ($manager, $application) {
            $application = ClanApplication::query()->lockForUpdate()->findOrFail($application->id);
            if ($application->status !== ClanApplication::PENDING) {
                throw new ClanException('Cette candidature a déjà été traitée.');
            }

            $this->closeApplication($application, ClanApplication::REFUSED);
            $this->notifications->clanRefused($application, $manager);
            Realtime::send(new ClanUpdated($application->clan_id, [ClanUpdated::MEMBERS]));
        });
    }

    // the clan is disbanded (Clan::booted)
    public function cancelApplicationsOf(Clan $clan): void
    {
        DB::transaction(fn () => $this->closeApplications(ClanApplication::query()->where('clan_id', $clan->id), ClanApplication::CANCELLED));
    }

    // the pending applications of the query, closed with this status and paid back
    private function closeApplications(Builder $query, string $status): void
    {
        $applications = $query->where('status', ClanApplication::PENDING)->lockForUpdate()->get();
        foreach ($applications as $application) {
            $this->closeApplication($application, $status);
        }
    }

    private function closeApplication(ClanApplication $application, string $status): void
    {
        $this->refund($application);
        $application->update(['status' => $status]);
        $this->notifications->clanApplicationClosed($application);
    }

    // the Kado points of an application given back, once
    private function refund(ClanApplication $application): void
    {
        if ($application->cost <= 0 || $application->refunded_at) {
            return;
        }

        $user = User::query()->findOrFail($application->user_id);
        $user->increment('kado_points', $application->cost);
        $user->userPoints()->create([
            'delta' => $application->cost,
            'reason' => 'clan application refund',
            'source_type' => ClanApplication::class,
            'source_id' => $application->id,
        ]);
        $application->update(['refunded_at' => now()]);
    }

    // Kado points taken from a player locked by the caller
    private function spend(User $user, int $price, string $reason, string $sourceType, int $sourceId): void
    {
        if ($price <= 0) {
            return;
        }

        $user->decrement('kado_points', $price);
        $user->userPoints()->create([
            'delta' => -$price,
            'reason' => $reason,
            'source_type' => $sourceType,
            'source_id' => $sourceId,
        ]);
    }

    // the last member leaving disbands the clan; the leader must give the leadership to someone else first
    public function leave(User $user): void
    {
        $clan = $this->clanOf($user);
        if (!$clan) {
            throw new ClanException('Vous ne faites partie d\'aucun clan.');
        }

        DB::transaction(function () use ($clan, $user) {
            // the clan locked, then its members: a leadership given to him or a kick at the same time waits
            $clan = $this->lockClan($clan, [$user->id]);
            $this->assertMember($user, $clan);
            $membersCount = $clan->members()->count();
            if ($clan->leader_id === $user->id && $membersCount > 1) {
                throw new ClanException('Vous devez d\'abord nommer un nouveau chef de clan.');
            }
            if ($this->isNewMember($user, $clan)) {
                throw new ClanException('Vous avez rejoint ce clan pendant cette période : vous pourrez le quitter à partir de la prochaine période.');
            }

            $clan->members()->where('user_id', $user->id)->delete();
            $this->forgetClanActions($user, $clan);
            if ($membersCount <= 1) {
                $clan->delete();
            } else {
                Realtime::send(new ClanUpdated($clan->id, [ClanUpdated::MEMBERS]));
            }
        });
    }

    public function kick(User $manager, Clan $clan, User $member): void
    {
        DB::transaction(function () use ($manager, $clan, $member) {
            $clan = $this->lockClan($clan, [$manager->id, $member->id]);
            $this->assertManager($manager, $clan);
            if ($member->id === $manager->id) {
                throw new ClanException('Vous ne pouvez pas vous exclure vous-même.');
            }
            if ($member->id === $clan->leader_id) {
                throw new ClanException('Le chef de clan ne peut pas être exclu.');
            }
            $this->assertMember($member, $clan);
            if ($this->isNewMember($member, $clan)) {
                throw new ClanException('Ce joueur a rejoint le clan pendant cette période : il pourra être exclu à partir de la prochaine période.');
            }

            $clan->members()->where('user_id', $member->id)->delete();
            $this->forgetClanActions($member, $clan);
            // (the excluded one too, his pages still listen to the clan: they see he is out)
            Realtime::send(new ClanUpdated($clan->id, [ClanUpdated::MEMBERS]));
        });
    }

    // the former leader becomes a right hand
    public function transferLeadership(User $leader, Clan $clan, User $member): void
    {
        DB::transaction(function () use ($leader, $clan, $member) {
            // the new leader can't leave nor be kicked meanwhile
            $clan = $this->lockClan($clan, [$leader->id, $member->id]);
            $this->assertLeader($leader, $clan);
            $this->assertMember($member, $clan);

            $clan->update(['leader_id' => $member->id]);
            $clan->members()->where('user_id', $member->id)->update(['role' => ClanRole::MEMBER]);
            $clan->members()->where('user_id', $leader->id)->update(['role' => ClanRole::RIGHT_HAND]);
            Realtime::send(new ClanUpdated($clan->id, [ClanUpdated::MEMBERS]));
        });
    }

    // the clan read again and locked, then the rows of these members (in the order of their ids, as everywhere)
    /**
     * @param  array<int, int>  $userIds
     */
    private function lockClan(Clan $clan, array $userIds): Clan
    {
        $clan = Clan::query()->lockForUpdate()->find($clan->id) ?? throw new ClanException('Ce clan n\'existe plus.');
        ClanMember::query()->where('clan_id', $clan->id)->whereIn('user_id', $userIds)->orderBy('id')->lockForUpdate()->get();

        return $clan;
    }

    // out of the clan: the clan runs he asked for are forgotten, the ones he began no longer count for it (if the run ends
    // anyway, it is a normal run)
    private function forgetClanActions(User $user, Clan $clan): void
    {
        $actions = ClanAction::query()->where('user_id', $user->id)->where('clan_id', $clan->id)->whereNull('completed_at');
        $actions->clone()->whereNull('run_id')->delete();
        $actions->clone()->update(['result' => 'cancelled', 'completed_at' => now()]);
    }

    // "Bras droit" or member
    public function setRole(User $manager, Clan $clan, User $member, ClanRole $role): void
    {
        $this->assertManager($manager, $clan);
        if ($role === ClanRole::LEADER) {
            throw new ClanException('Utilisez « Nommer chef » pour donner la direction du clan.');
        }
        if ($member->id === $clan->leader_id) {
            throw new ClanException('Le rôle du chef de clan ne peut pas être changé.');
        }
        $this->assertMember($member, $clan);

        $clan->members()->where('user_id', $member->id)->update(['role' => $role]);
        Realtime::send(new ClanUpdated($clan->id, [ClanUpdated::MEMBERS]));
    }

    // "Attaquant", "Défenseur" or none, within the seats of the clan; then locked until the next period
    public function setCombatRole(User $manager, Clan $clan, User $member, ?ClanCombatRole $role): void
    {
        $this->assertManager($manager, $clan);
        $this->assertMember($member, $clan);
        $period = $this->assertPeriod();

        DB::transaction(function () use ($clan, $member, $role, $period) {
            $current = ClanMember::query()->where('clan_id', $clan->id)->where('user_id', $member->id)->first();
            if ($current->combat_role === $role) {
                return;
            }
            if ($current->combat_role_period_id === $period->id) {
                throw new ClanException('Le siège de ce joueur a déjà été choisi pendant cette période : il pourra changer à la prochaine période.');
            }
            if ($role) {
                // the clan is locked (PostgreSQL does not lock an aggregate): one seat given at a time
                Clan::query()->lockForUpdate()->find($clan->id);
                $taken = $clan->members()->where('combat_role', $role)->where('user_id', '!=', $member->id)->count();
                $seats = $this->combatSeats($clan, $role);
                if ($taken >= $seats) {
                    throw new ClanException("Tous les sièges de {$role->getLabel()} sont pris ({$seats} pour ce clan).");
                }
            }
            $clan->members()->where('user_id', $member->id)->update(['combat_role' => $role, 'combat_role_period_id' => $period->id]);
            Realtime::send(new ClanUpdated($clan->id, [ClanUpdated::MEMBERS]));
        });
    }

    // the status of a member in the list of the members, seen by the clan only: his own, or anyone's for the leader and the
    // right hands
    public function setStatus(User $user, Clan $clan, User $member, ?string $status): void
    {
        $this->assertMember($member, $clan);
        if ($user->id !== $member->id) {
            $this->assertManager($user, $clan);
        }

        $status = trim($status ?? '');
        $clan->members()->where('user_id', $member->id)->update(['status' => $status !== '' ? $status : null]);
        Realtime::send(new ClanUpdated($clan->id, [ClanUpdated::MEMBERS]));
    }

    // accepted in the clan during the current period: he can't leave nor be excluded before the next one
    public function isNewMember(User $user, Clan $clan): bool
    {
        $periodId = $this->currentPeriod()?->id;

        return $periodId !== null && ClanMember::query()
            ->where('clan_id', $clan->id)
            ->where('user_id', $user->id)
            ->where('joined_period_id', $periodId)
            ->exists();
    }

    // the clan and all it did (scores, attacks, missions) are deleted
    public function dissolve(User $leader, Clan $clan): void
    {
        $this->assertLeader($leader, $clan);

        // (sent first: the members see their clan is gone)
        Realtime::send(new ClanUpdated($clan->id, [ClanUpdated::MEMBERS]));
        $clan->delete();
    }

    // ---------------------------------------------------------------- scores

    // what the pages show, without creating it (0 everywhere when the clan did not play yet)
    public function existingPeriodScore(Clan $clan, Period $period): ?ClanPeriodScore
    {
        return ClanPeriodScore::query()->where('clan_id', $clan->id)->where('period_id', $period->id)->first();
    }

    // created the first time the clan plays in the period, with the "Jeu cool" and "Jeu caca" options given to every clan
    public function periodScore(Clan $clan, Period $period): ClanPeriodScore
    {
        $score = ClanPeriodScore::query()->firstOrCreate(['clan_id' => $clan->id, 'period_id' => $period->id]);
        if (!$score->wasRecentlyCreated) {
            return $score;
        }

        if ($period->end_at->isFuture()) {
            foreach ([ClanBonusType::FORCE_GAME, ClanBonusType::BAN_GAME] as $type) {
                ClanBonus::query()->create(['clan_id' => $clan->id, 'period_id' => $period->id, 'type' => $type]);
            }
        }

        // (the default values of the columns)
        return $score->refresh();
    }

    // the clan runs he asked for but did not begin: a new one replaces them (he chose another game, left the page...)
    public function forgetUnplayedActions(User $user): void
    {
        ClanAction::query()
            ->where('user_id', $user->id)
            ->whereNull('run_id')
            ->whereNull('completed_at')
            ->delete();
    }

    public function warScore(Clan $clan, Period $period): int
    {
        return (int) (ClanPeriodScore::query()->where('clan_id', $clan->id)->where('period_id', $period->id)->value('war_score') ?? 0);
    }

    public function memberStat(int $clanId, int $userId, int $periodId): ClanMemberStat
    {
        $stat = ClanMemberStat::query()->firstOrCreate(['clan_id' => $clanId, 'user_id' => $userId, 'period_id' => $periodId]);

        return $stat->wasRecentlyCreated ? $stat->refresh() : $stat;
    }

    // max points against a clan with as many points or more, one less by palier (protection_range / max points) the
    // defender has below the attacker, at least 1
    public function attackPoints(int $attackerScore, int $defenderScore): int
    {
        $settings = app(ClanSettings::class);
        $max = $settings->attack_max_points;
        $palier = max(1, $settings->protection_range / max(1, $max));
        $below = max(0, $attackerScore - $defenderScore);

        return max(1, $max - (int) ceil($below / $palier));
    }

    public function isProtected(int $attackerScore, int $defenderScore): bool
    {
        return abs($attackerScore - $defenderScore) > app(ClanSettings::class)->protection_range;
    }

    /**
     * The clans with their scores of the period (0 without any), best first.
     *
     * @param  'war'|'missions'  $ranking
     */
    public function rankingQuery(Period $period, string $ranking = 'war'): Builder
    {
        $column = $ranking === 'missions' ? 'mission_score' : 'war_score';

        return Clan::query()
            ->leftJoin('clan_period_scores', function ($join) use ($period) {
                $join->on('clan_period_scores.clan_id', '=', 'clans.id')
                    ->where('clan_period_scores.period_id', '=', $period->id);
            })
            ->select('clans.*')
            ->selectRaw('COALESCE(clan_period_scores.war_score, 0) as war_score')
            ->selectRaw('COALESCE(clan_period_scores.mission_score, 0) as mission_score')
            ->selectRaw('COALESCE(clan_period_scores.attacks_won, 0) as attacks_won')
            ->selectRaw('COALESCE(clan_period_scores.defenses_won, 0) as defenses_won')
            ->selectRaw('COALESCE(clan_period_scores.missions_completed, 0) as missions_completed')
            ->orderByRaw("COALESCE(clan_period_scores.{$column}, 0) desc")
            ->orderBy('clans.id');
    }

    // the ranks of these clans in the whole ranking, in one query: the position in the same order as rankingQuery
    /**
     * @param  array<int, int>  $clanIds
     * @param  'war'|'missions'  $ranking
     * @return \Illuminate\Support\Collection<int, int> by clan id
     */
    public function ranksOf(array $clanIds, Period $period, string $ranking = 'war')
    {
        $column = $ranking === 'missions' ? 'mission_score' : 'war_score';
        $ranked = Clan::query()
            ->leftJoin('clan_period_scores', function ($join) use ($period) {
                $join->on('clan_period_scores.clan_id', '=', 'clans.id')
                    ->where('clan_period_scores.period_id', '=', $period->id);
            })
            ->select('clans.id')
            ->selectRaw("ROW_NUMBER() OVER (ORDER BY COALESCE(clan_period_scores.{$column}, 0) DESC, clans.id) as position");

        return DB::query()->fromSub($ranked, 'ranked')->whereIn('id', $clanIds)->pluck('position', 'id')->map(fn ($rank) => (int) $rank);
    }

    public function rankOf(Clan $clan, Period $period, string $ranking = 'war'): int
    {
        $column = $ranking === 'missions' ? 'mission_score' : 'war_score';
        $score = (int) (ClanPeriodScore::query()->where('clan_id', $clan->id)->where('period_id', $period->id)->value($column) ?? 0);

        // same order as rankingQuery: score, then the oldest clan first
        $better = ClanPeriodScore::query()
            ->where('period_id', $period->id)
            ->where(function ($query) use ($column, $score, $clan) {
                $query->where($column, '>', $score)
                    ->orWhere(fn ($q) => $q->where($column, $score)->where('clan_id', '<', $clan->id));
            })
            ->count();

        // the clans without any score of the period are ranked after, by id
        if ($score === 0) {
            $better += Clan::query()
                ->where('id', '<', $clan->id)
                ->whereDoesntHave('periodScores', fn ($q) => $q->where('period_id', $period->id))
                ->count();
        }

        return $better + 1;
    }
}
