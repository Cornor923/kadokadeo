<?php

namespace App\Services;

use App\Models\Game;
use App\Models\Period;
use App\Models\PoidsPlumeResult;
use App\Models\User;
use App\Settings\SiteSettings;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class PoidsPlumeService
{
    // players with fewer feathers (and the jackpot winners) get nothing from the shared pool
    public const SHARED_POOL_MIN_FEATHERS = 2;

    public function __construct(
        private readonly LeagueService $leagueService,
        private readonly ScoreService $scoreService,
    ) {}

    public function closePeriod(Period $period): void
    {
        $paradiseLeague = $this->leagueService->getParadiseLeague();
        $feathersByUser = $this->getFeathersByUser($period, $paradiseLeague->id);

        if ($feathersByUser === []) {
            return;
        }

        $rewards = $this->computeRewards(array_map('count', $feathersByUser));

        DB::transaction(function () use ($period, $feathersByUser, $rewards) {
            foreach ($feathersByUser as $userId => $gameIds) {
                sort($gameIds);

                $result = PoidsPlumeResult::query()->firstOrCreate(
                    [
                        'period_id' => $period->id,
                        'user_id' => $userId,
                    ],
                    [
                        'game_ids' => $gameIds,
                        'feathers_count' => count($gameIds),
                        'jackpot_total' => $rewards['jackpot_total'],
                        'shared_pool_total' => $rewards['shared_pool_total'],
                        'reward' => $rewards['players'][$userId]['reward'],
                    ]
                );

                if ($result->reward <= 0 || $result->user_point_id) {
                    continue;
                }

                $user = $result->user;
                $user->increment('kado_points', $result->reward);

                $userPoint = $user->userPoints()->create([
                    'period_id' => $period->id,
                    'delta' => $result->reward,
                    'reason' => $rewards['players'][$userId]['is_jackpot_winner'] ? 'poids plume jackpot' : 'poids plume shared pool',
                    'source_type' => PoidsPlumeResult::class,
                    'source_id' => $result->id,
                ]);

                $result->user_point_id = $userPoint->id;
                $result->save();
            }
        });
    }

    /**
     * Feather leaderboard of a period with the reward of each player: the one paid for a closed period,
     * the one the player would get with the current settings otherwise.
     */
    public function getLeaderboardForPeriod(?Period $period): Collection
    {
        $players = [];

        if ($period) {
            $results = $period->poidsPlumeResults()->get(['user_id', 'feathers_count', 'reward']);

            if ($results->isNotEmpty()) {
                $maxFeathers = $results->max('feathers_count');
                foreach ($results as $result) {
                    $players[$result->user_id] = [
                        'feathers_count' => $result->feathers_count,
                        'reward' => $result->reward,
                        'is_jackpot_winner' => $result->feathers_count === $maxFeathers,
                    ];
                }
            } else {
                $paradiseLeague = $this->leagueService->getParadiseLeague();
                $feathersCountByUser = array_map('count', $this->getFeathersByUser($period, $paradiseLeague->id));
                $rewards = $this->computeRewards($feathersCountByUser);
                foreach ($feathersCountByUser as $userId => $feathersCount) {
                    $players[$userId] = ['feathers_count' => $feathersCount] + $rewards['players'][$userId];
                }
            }
        }

        return User::query()
            ->whereIn('id', array_keys($players))
            ->get(['id', 'etwin_id', 'display_name'])
            ->map(fn (User $user) => [
                'user' => [
                    'etwin_id' => $user->etwin_id,
                    'display_name' => $user->display_name,
                ],
            ] + $players[$user->id])
            ->sort(fn ($leftPlayer, $rightPlayer) => ($rightPlayer['feathers_count'] <=> $leftPlayer['feathers_count'])
                ?: strcasecmp($leftPlayer['user']['display_name'], $rightPlayer['user']['display_name']))
            ->values()
            ->map(fn ($player, $index) => ['rank' => $index + 1] + $player);
    }

    /**
     * The jackpot is shared between the players with the most feathers, the shared pool equally between
     * the other players with at least SHARED_POOL_MIN_FEATHERS feathers (the remainders are lost).
     *
     * @param  array<int, int>  $feathersCountByUser
     * @return array{jackpot_total: int, shared_pool_total: int, players: array<int, array{reward: int, is_jackpot_winner: bool}>}
     */
    private function computeRewards(array $feathersCountByUser): array
    {
        $settings = app(SiteSettings::class);
        $jackpotTotal = max(0, $settings->poids_plume_jackpot);
        $sharedPoolTotal = max(0, $settings->poids_plume_shared_pool);

        $maxFeathers = $feathersCountByUser === [] ? 0 : max($feathersCountByUser);
        $jackpotWinners = array_filter($feathersCountByUser, fn (int $feathersCount) => $feathersCount === $maxFeathers);
        $sharedPoolPlayers = array_filter(
            $feathersCountByUser,
            fn (int $feathersCount) => $feathersCount !== $maxFeathers && $feathersCount >= self::SHARED_POOL_MIN_FEATHERS,
        );
        $jackpotShare = count($jackpotWinners) > 0 ? intdiv($jackpotTotal, count($jackpotWinners)) : 0;
        $sharedPoolShare = count($sharedPoolPlayers) > 0 ? intdiv($sharedPoolTotal, count($sharedPoolPlayers)) : 0;

        $players = [];
        foreach ($feathersCountByUser as $userId => $feathersCount) {
            $isJackpotWinner = array_key_exists($userId, $jackpotWinners);
            $players[$userId] = [
                'reward' => match (true) {
                    $isJackpotWinner => $jackpotShare,
                    array_key_exists($userId, $sharedPoolPlayers) => $sharedPoolShare,
                    default => 0,
                },
                'is_jackpot_winner' => $isJackpotWinner,
            ];
        }

        return [
            'jackpot_total' => $jackpotTotal,
            'shared_pool_total' => $sharedPoolTotal,
            'players' => $players,
        ];
    }

    private function getFeathersByUser(Period $period, int $paradiseLeagueId): array
    {
        $feathersByUser = [];

        foreach (Game::query()->get() as $game) {
            $winnerRun = $this->scoreService->getLeaderBoard($game, $period->id, $paradiseLeagueId)->first();

            if ($winnerRun) {
                $feathersByUser[$winnerRun->user_id][] = $game->id;
            }
        }

        return $feathersByUser;
    }
}
