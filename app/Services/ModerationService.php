<?php

namespace App\Services;

use App\Enums\BanReason;
use App\Events\DailyScoresChanged;
use App\Events\GameScoresChanged;
use App\Events\UserCountersChanged;
use App\Events\UserRefresh;
use App\Models\Game;
use App\Models\GamePeriodStar;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use App\Models\UserPoint;
use App\Models\UserStar;
use App\Support\Realtime;
use App\Support\ScoreBoards;
use Closure;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;

class ModerationService
{
    // the counters of user_stars, by star (RunService::rewardStars)
    private const STAR_COLUMNS = ['green_stars', 'orange_stars', 'red_stars', 'purple_stars'];

    // the counters of a player the admin adjusts (UserForm shows them read-only)
    public const GAME_COUNTERS = ['kado_games', 'clan_games', 'clan_attack_games'];

    /**
     * Soft-deletes every run of the user (they can be restored from the admin) and removes the stars they earned.
     * Returns the number of deleted runs.
     */
    public function deleteScores(User $user): int
    {
        return $this->deleteScoresAfter($user);
    }

    /**
     * Deletes the scores of the user and bans them: they can no longer log in, and their sessions are refused
     * by App\Http\Middleware\EnsureUserIsNotBanned. Returns the number of deleted runs.
     */
    public function ban(User $user, BanReason $reason): int
    {
        // banned first, in the transaction of the deletion: a run finishing meanwhile (its row locked by
        // RunService::confirmRun) is deleted once it is saved, a run not saved yet is refused (deleted)
        return $this->deleteScoresAfter($user, fn () => $user->update([
            'banned_at' => now(),
            'ban_reason' => $reason,
        ]));
    }

    // the deleted scores are not restored
    public function unban(User $user): void
    {
        $user->update([
            'banned_at' => null,
            'ban_reason' => null,
        ]);
    }

    /**
     * A run deleted from the admin: out of the leaderboards, its contract points taken back and the stars of the
     * player in its game and period computed again from the runs left. Soft-deleted, restoreRun gives them back.
     */
    public function deleteRun(Run $run, bool $force = false): bool
    {
        DB::transaction(function () use ($run, $force) {
            $force ? $run->forceDelete() : $run->delete();
            $this->takeBackContractPoints($run);
            $this->recomputeStars($run);
        });
        $this->forgetPromotionScores($run);
        ScoreBoards::changed($run);
        Realtime::send(new UserRefresh($run->user_id));

        return true;
    }

    /**
     * A deleted run restored from the admin: back in the leaderboards, with its stars and the contract points
     * deleteRun took back (the runs deleted by deleteScores kept theirs). Returns false when it was not deleted.
     */
    public function restoreRun(Run $run): bool
    {
        if (!$run->trashed()) {
            return false;
        }

        DB::transaction(function () use ($run) {
            $run->restore();
            $takenBack = (int) $this->contractPoints($run)->whereIn('reason', ['deleted run', 'restored run'])->sum('delta');
            if ($takenBack < 0) {
                $this->giveContractPoints($run, -$takenBack, 'restored run');
            }
            $this->recomputeStars($run);
        });
        $this->forgetPromotionScores($run);
        ScoreBoards::changed($run);
        Realtime::send(new UserRefresh($run->user_id));

        return true;
    }

    /**
     * Kado points given (or taken back, below 0 like RunService::flagAsCheat) by an admin: added to the balance of
     * the moment, with a user_points row. Returns the new balance.
     */
    public function adjustKadoPoints(User $user, int $delta, User $admin): int
    {
        if ($delta === 0) {
            throw new InvalidArgumentException('The delta must not be 0.');
        }

        return DB::transaction(function () use ($user, $delta, $admin) {
            User::query()->whereKey($user->id)->increment('kado_points', $delta);
            Realtime::send(new UserCountersChanged($user->id));
            $user->userPoints()->create([
                'period_id' => Period::current()->value('id'),
                'delta' => $delta,
                'reason' => 'admin adjustment',
                'source_type' => User::class,
                'source_id' => $admin->id,
            ]);

            return (int) User::query()->whereKey($user->id)->value('kado_points');
        });
    }

    /**
     * Games given (or taken back) by an admin, added to the counters of the moment (GAME_COUNTERS => delta).
     * A counter never goes below 0: nothing is changed then and false is returned.
     */
    public function adjustGames(User $user, array $deltas): bool
    {
        $deltas = array_filter(array_intersect_key(array_map('intval', $deltas), array_flip(self::GAME_COUNTERS)));
        if (!$deltas) {
            return true;
        }

        $query = User::query()->whereKey($user->id);
        foreach ($deltas as $column => $delta) {
            if ($delta < 0) {
                $query->where($column, '>=', -$delta);
            }
        }

        $changed = $query->toBase()->incrementEach($deltas, ['updated_at' => now()]) > 0;
        if ($changed) {
            Realtime::send(new UserCountersChanged($user->id));
        }

        return $changed;
    }

    private function deleteScoresAfter(User $user, ?Closure $before = null): int
    {
        [$deleted, $promotionCaches] = DB::transaction(function () use ($user, $before) {
            if ($before) {
                $before();
            }

            // leaderboards used to compute the league promotions of the next period (and shown by the pages)
            $boards = $user->runs()
                ->whereNotNull('period_id')
                ->select('game_id', 'period_id')
                ->distinct()
                ->get();
            $promotionCaches = $boards->map(fn ($run) => $this->promotionScoresKey($run));
            $boards->each(fn (Run $run) => Realtime::send(new GameScoresChanged($run->game_id, $run->period_id, null)));
            $user->runs()->whereNotNull('daily_game_id')->distinct()->pluck('daily_game_id')
                ->each(fn (int $dailyGameId) => Realtime::send(new DailyScoresChanged($dailyGameId)));

            $deleted = $user->runs()->delete();
            $user->gamePeriodStars()->delete();
            $user->stars()->delete();

            return [$deleted, $promotionCaches];
        });

        $promotionCaches->each(fn (string $key) => cache()->forget($key));

        return $deleted;
    }

    // the leaderboard used to compute the league promotions of the game in the period of the run (cached by
    // ScoreService, forgotten like RunService::forgetPromotionScores: RunService needs the RSA keys to be built)
    private function promotionScoresKey(Run $run): string
    {
        return "promotion_scores_{$run->game_id}_{$run->period_id}";
    }

    private function forgetPromotionScores(Run $run): void
    {
        if ($run->period_id) {
            cache()->forget($this->promotionScoresKey($run));
        }
    }

    // the user_points rows of a run: its contract points (RunService::confirmRun), taken back (flagAsCheat, deleteRun)
    // or given back (restoreRun)
    private function contractPoints(Run $run)
    {
        return UserPoint::query()->where('source_type', Run::class)->where('source_id', $run->id);
    }

    // the contract points of the run taken back (what is left of them: called again, it takes nothing more)
    private function takeBackContractPoints(Run $run): void
    {
        $reward = (int) $this->contractPoints($run)->sum('delta');
        if ($reward > 0) {
            $this->giveContractPoints($run, -$reward, 'deleted run');
        }
    }

    private function giveContractPoints(Run $run, int $delta, string $reason): void
    {
        User::query()->whereKey($run->user_id)->increment('kado_points', $delta);
        Realtime::send(new UserCountersChanged($run->user_id));
        UserPoint::query()->create([
            'user_id' => $run->user_id,
            'period_id' => $run->period_id,
            'delta' => $delta,
            'reason' => $reason,
            'source_type' => Run::class,
            'source_id' => $run->id,
        ]);
    }

    // the stars of the player in the game and period of the run, from the best score of the runs left
    // (RunService::rewardStars gives each star once, up to the star of the score; also used by RunService::flagAsCheat)
    public function recomputeStars(Run $run): void
    {
        if (!$run->period_id) {
            return;
        }

        $best = Run::query()
            ->where('period_id', $run->period_id)
            ->where('game_id', $run->game_id)
            ->where('user_id', $run->user_id)
            ->whereNotNull('score')
            ->where('is_cheat', false)
            ->max('score');
        $gainedStar = $best === null ? -1 : Game::query()->findOrFail($run->game_id)->getStarFromScore((int) $best);

        $now = now();
        $changes = [];
        foreach (self::STAR_COLUMNS as $star => $column) {
            $row = ['game_id' => $run->game_id, 'period_id' => $run->period_id, 'user_id' => $run->user_id, 'star' => $star];
            if ($star <= $gainedStar) {
                if (GamePeriodStar::query()->insertOrIgnore([...$row, 'created_at' => $now, 'updated_at' => $now]) > 0) {
                    $changes[$column] = 1;
                }
            } elseif (GamePeriodStar::query()->where($row)->delete() > 0) {
                $changes[$column] = -1;
            }
        }

        if ($changes) {
            $userStars = UserStar::query()->firstOrCreate(['user_id' => $run->user_id, 'period_id' => $run->period_id]);
            UserStar::query()->whereKey($userStars->getKey())->incrementEach($changes);
        }
    }
}
