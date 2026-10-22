<?php

namespace App\Services;

use App\Models\ClanMemberStat;
use App\Models\LeaguePromotion;
use App\Models\Period;
use App\Models\PoidsPlumeResult;
use App\Models\User;
use App\Models\UserStar;
use Illuminate\Database\Eloquent\Collection as EloquentCollection;

/**
 * The summary of a finished period for a player (the tab « dernière période » of the profile): the Kado points it
 * brought at its close (the ranking of their clan, the promotions in the leagues, the feathers), the stars of the period
 * (they bring no Kado points on KadoKadéo), and their ranking in each game.
 */
class PeriodSummaryService
{
    public function __construct(private readonly ScoreService $scoreService) {}

    // the finished periods: their end is past (the current one, still played, has no summary yet)
    public function finishedPeriods()
    {
        return Period::query()->where('end_at', '<', now());
    }

    public function lastFinishedPeriod(): ?Period
    {
        return $this->finishedPeriods()->orderByDesc('end_at')->first();
    }

    public function isFinished(Period $period): bool
    {
        return $period->end_at->isPast();
    }

    public function summary(User $user, Period $period): array
    {
        // (a player who changed clan during the period has a line in each: the clan shown is the one that paid most)
        $clanStats = ClanMemberStat::query()
            ->with('clan:id,name')
            ->where('user_id', $user->id)
            ->where('period_id', $period->id)
            ->get();
        $clanStat = $clanStats->sortByDesc('reward')->first();
        $promotions = LeaguePromotion::query()
            ->with('game:id,name')
            ->where('user_id', $user->id)
            ->where('period_id', $period->id)
            ->orderByDesc('promotion_reward')
            ->get();
        $feathers = PoidsPlumeResult::query()
            ->where('user_id', $user->id)
            ->where('period_id', $period->id)
            ->first();
        $stars = UserStar::query()
            ->where('user_id', $user->id)
            ->where('period_id', $period->id)
            ->first();

        $clanReward = (int) $clanStats->sum('reward') ?: null;
        $promotionsReward = (int) $promotions->sum('promotion_reward');
        $feathersReward = $feathers?->reward ?: null;

        $rankings = EloquentCollection::make($this->scoreService->getUserBestRuns($user, $period->id))->load('game');

        return [
            'period' => [
                'id' => $period->id,
                'start_at' => $period->start_at,
                'end_at' => $period->end_at,
            ],
            // the finished periods around it, for the buttons « période précédente / suivante »
            'previous_period_id' => $this->finishedPeriods()->where('end_at', '<', $period->end_at)->orderByDesc('end_at')->value('id'),
            'next_period_id' => $this->finishedPeriods()->where('end_at', '>', $period->end_at)->orderBy('end_at')->value('id'),
            'clan' => $clanStat ? ['id' => $clanStat->clan?->id, 'name' => $clanStat->clan?->name, 'reward' => $clanReward] : null,
            'promotions' => $promotions->map(fn (LeaguePromotion $promotion) => [
                'game' => ['id' => $promotion->game->id, 'name' => $promotion->game->name],
                'rank_position' => $promotion->rank_position,
                'from_league_id' => $promotion->from_league_id,
                'to_league_id' => $promotion->to_league_id,
                'score' => $promotion->score,
                'reward' => $promotion->promotion_reward,
            ])->values(),
            'promotions_reward' => $promotionsReward ?: null,
            'feathers' => $feathers ? ['count' => $feathers->feathers_count, 'reward' => $feathersReward] : null,
            'stars' => [
                'green' => (int) ($stars->green_stars ?? 0),
                'orange' => (int) ($stars->orange_stars ?? 0),
                'red' => (int) ($stars->red_stars ?? 0),
                'purple' => (int) ($stars->purple_stars ?? 0),
            ],
            'total' => ($clanReward ?? 0) + $promotionsReward + ($feathersReward ?? 0),
            'rankings' => $rankings->values(),
        ];
    }
}
