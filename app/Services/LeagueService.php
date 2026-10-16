<?php

namespace App\Services;

use App\Achievements\Events\LeagueChanged;
use App\Models\Game;
use App\Models\League;
use App\Models\LeagueMembership;
use App\Models\LeaguePromotion;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class LeagueService
{
    public function __construct(private readonly ScoreService $scoreService, private readonly AchievementService $achievementService) {}

    public function getBeginnerLeague(): League
    {
        return League::query()->where('level', 1)->firstOrFail();
    }

    public function getParadiseLeague(): League
    {
        return League::query()->where('level', 5)->firstOrFail();
    }

    public function getCurrentLeagueFor(User $user, Game $game, Period $period): League
    {
        $membership = LeagueMembership::query()
            ->with('league')
            ->where('user_id', $user->id)
            ->where('game_id', $game->id)
            ->where('period_id', $period->id)
            ->first();

        if ($membership?->league) {
            return $membership->league;
        }

        $latestMembership = LeagueMembership::query()
            ->with('league')
            ->where('user_id', $user->id)
            ->where('game_id', $game->id)
            ->where('period_id', '<', $period->id)
            ->orderByDesc('period_id')
            ->first();

        return $latestMembership?->league ?? $this->getBeginnerLeague();
    }

    public function getCurrentLeagues(User $user, ?int $periodId = null): array
    {
        $memberships = LeagueMembership::query()
            ->with('league')
            ->where('user_id', $user->id)
            ->when($periodId, fn ($query) => $query->where('period_id', $periodId))
            ->get();

        $leaguesByGame = [];
        foreach ($memberships as $membership) {
            if ($membership->league) {
                $leaguesByGame[$membership->game_id] = $membership->league;
            }
        }

        return $leaguesByGame;
    }

    public function resolveMembership(User $user, Game $game, Period $period): LeagueMembership
    {
        $league = $this->getCurrentLeagueFor($user, $game, $period);

        return $this->storeHighestMembership($user->id, $game->id, $period->id, $league);
    }

    public function getPromotionSlots(League $league, int $activePlayersCount): int
    {
        return $league->getPromotionSlots($activePlayersCount);
    }

    /**
     * Nobody played in the league during the period: the first player is promoted alone (with the stars),
     * unless the next league is empty too (see promoteEligiblePlayers).
     */
    public function canBePromotedAlone(Game $game, Period $period, League $league): bool
    {
        $nextLeague = League::query()->where('level', $league->level + 1)->first();
        if (!$nextLeague || $this->getPromotionSlots($league, 1) <= 0) {
            return false;
        }

        return LeagueMembership::query()->where('game_id', $game->id)->where('period_id', $period->id)->where('league_id', $nextLeague->id)->exists();
    }

    /**
     * Games where the user would be promoted if the period ended now. Read from the promotion cache of each game
     * the user played during the period (ScoreService::getLeagueScoresForPromotion).
     *
     * @param  Collection<int, Game>|null  $games  games already loaded (the others are ignored)
     * @return int[]
     */
    public function getPromotionGameIds(User $user, int $periodId, ?Collection $games = null): array
    {
        $playedGameIds = LeagueMembership::query()->where('user_id', $user->id)->where('period_id', $periodId)->pluck('game_id');
        if ($playedGameIds->isEmpty()) {
            return [];
        }

        $games = $games
            ? $games->whereIn('id', $playedGameIds)
            : Game::query()->whereIn('id', $playedGameIds)->get();

        return $games
            ->filter(fn (Game $game) => $this->scoreService->getLeagueScoresForPromotion($game, $periodId)
                ->contains(fn (array $leagueScore) => in_array($user->id, $leagueScore['promoted_user_ids'] ?? [], true)))
            ->pluck('id')
            ->values()
            ->all();
    }

    public function closePeriod(Period $period, Period $nextPeriod): void
    {
        DB::transaction(function () use ($period, $nextPeriod) {
            $this->carryMembershipsToNextPeriod($period, $nextPeriod);
            $this->promoteEligiblePlayers($period, $nextPeriod);
        });
    }

    private function carryMembershipsToNextPeriod(Period $period, Period $nextPeriod): void
    {
        LeagueMembership::query()
            ->where('period_id', $period->id)
            ->with('league')
            ->chunkById(500, function ($memberships) use ($nextPeriod) {
                foreach ($memberships as $membership) {
                    if (!$membership->league) {
                        continue;
                    }

                    $this->storeHighestMembership(
                        $membership->user_id,
                        $membership->game_id,
                        $nextPeriod->id,
                        $membership->league
                    );
                }
            });
    }

    private function promoteEligiblePlayers(Period $period, Period $nextPeriod): void
    {
        $leagues = League::query()->ordered()->get()->keyBy('level');
        $games = Game::query()->get();

        foreach ($games as $game) {
            foreach ($leagues as $league) {
                $nextLeague = $leagues->get($league->level + 1);
                if (!$nextLeague) {
                    continue;
                }

                $leaderBoard = $this->scoreService->getLeaderBoard($game, $period->id, $league->id);
                $activePlayersCount = (clone $leaderBoard)->count();
                $promotionSlots = $this->getPromotionSlots($league, $activePlayersCount);
                if ($activePlayersCount === 1) {
                    $hasNextLeaguePlayers = LeagueMembership::query()->where('game_id', $game->id)->where('period_id', $period->id)->where('league_id', $nextLeague->id)->exists();
                    if (!$hasNextLeaguePlayers) {
                        continue;
                    }
                }

                if ($promotionSlots <= 0) {
                    continue;
                }

                $promotedRuns = $leaderBoard->take($promotionSlots)->get()
                    ->filter(fn (Run $run) => $this->hasRequiredStarsForPromotion($game, $league, $run));
                foreach ($promotedRuns as $run) {
                    $promotion = $this->createPromotion($period, $nextPeriod, $game, $league, $nextLeague, $run, $promotionSlots, $activePlayersCount);

                    $this->storeHighestMembership($run->user_id, $game->id, $nextPeriod->id, $nextLeague);
                    $this->rewardPromotion($promotion);
                    $this->achievementService->handleLeagueChanged(new LeagueChanged(
                        user: $run->user,
                        game: $game,
                        period: $nextPeriod,
                        fromLeague: $league,
                        toLeague: $nextLeague,
                        promotion: $promotion,
                    ));
                }
            }
        }
    }

    private function createPromotion(Period $period, Period $nextPeriod, Game $game, League $fromLeague, League $toLeague, Run $run, int $promotionSlots, int $activePlayersCount): LeaguePromotion
    {
        return LeaguePromotion::query()->firstOrCreate(
            [
                'period_id' => $period->id,
                'game_id' => $game->id,
                'user_id' => $run->user_id,
            ],
            [
                'next_period_id' => $nextPeriod->id,
                'from_league_id' => $fromLeague->id,
                'to_league_id' => $toLeague->id,
                'run_id' => $run->id,
                'rank_position' => $run->rank_position,
                'score' => $run->score,
                'play_time_seconds' => $run->play_time_seconds,
                'promotion_slots' => $promotionSlots,
                'active_players_count' => $activePlayersCount,
                'promotion_reward' => $fromLeague->promotion_reward ?? 0,
            ]
        );
    }

    private function rewardPromotion(LeaguePromotion $promotion): void
    {
        if ($promotion->user_point_id || $promotion->promotion_reward <= 0) {
            return;
        }

        $user = $promotion->user;
        $user->increment('kado_points', $promotion->promotion_reward);

        $userPoint = $user->userPoints()->create([
            'period_id' => $promotion->period_id,
            'delta' => $promotion->promotion_reward,
            'reason' => 'league promotion',
            'source_type' => LeaguePromotion::class,
            'source_id' => $promotion->id,
        ]);

        $promotion->user_point_id = $userPoint->id;
        $promotion->save();
    }

    private function hasRequiredStarsForPromotion(Game $game, League $league, Run $run): bool
    {
        if (is_null($league->promotion_min_stars)) {
            return true;
        }

        return $game->getStarFromScore($run->score) >= $league->promotion_min_stars;
    }

    private function storeHighestMembership(int $userId, int $gameId, int $periodId, League $league): LeagueMembership
    {
        $membership = LeagueMembership::query()->firstOrNew([
            'user_id' => $userId,
            'period_id' => $periodId,
            'game_id' => $gameId,
        ]);

        if (!$membership->exists) {
            $membership->league_id = $league->id;
            $membership->save();

            return $membership;
        }

        $currentLeagueLevel = League::query()->whereKey($membership->league_id)->value('level') ?? 0;
        if ($league->level > $currentLeagueLevel) {
            $membership->league_id = $league->id;
            $membership->save();
        }

        return $membership;
    }
}
