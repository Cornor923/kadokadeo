<?php

namespace App\Services;

use App\Models\Game;
use App\Models\Period;
use App\Models\PoidsPlumeResult;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class PoidsPlumeService
{
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

        $maxFeathers = max(array_map('count', $feathersByUser));
        $jackpotWinners = array_filter($feathersByUser, fn (array $gameIds) => count($gameIds) === $maxFeathers);
        $jackpotTotal = (int) config('kado.poids_plume.jackpot', 0);
        $jackpotShare = count($jackpotWinners) > 0 ? intdiv($jackpotTotal, count($jackpotWinners)) : 0;

        DB::transaction(function () use ($period, $feathersByUser, $jackpotWinners, $jackpotTotal, $jackpotShare) {
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
                        'jackpot_total' => $jackpotTotal,
                        'reward' => array_key_exists($userId, $jackpotWinners) ? $jackpotShare : 0,
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
                    'reason' => 'poids plume jackpot',
                    'source_type' => PoidsPlumeResult::class,
                    'source_id' => $result->id,
                ]);

                $result->user_point_id = $userPoint->id;
                $result->save();
            }
        });
    }

    public function getLeaderboardForPeriod(?Period $period): Collection
    {
        $feathersCountByUser = [];

        if ($period) {
            $paradiseLeague = $this->leagueService->getParadiseLeague();
            $feathersByUser = $this->getFeathersByUser($period, $paradiseLeague->id);
            $feathersCountByUser = array_map('count', $feathersByUser);
        }

        return User::query()
            ->whereIn('id', array_keys($feathersCountByUser))
            ->get(['id', 'etwin_id', 'display_name'])
            ->map(fn (User $user) => [
                'user' => [
                    'etwin_id' => $user->etwin_id,
                    'display_name' => $user->display_name,
                ],
                'feathers_count' => $feathersCountByUser[$user->id] ?? 0,
            ])
            ->sort(fn ($leftPlayer, $rightPlayer) => ($rightPlayer['feathers_count'] <=> $leftPlayer['feathers_count'])
                ?: strcasecmp($leftPlayer['user']['display_name'], $rightPlayer['user']['display_name']))
            ->values()
            ->map(fn ($player, $index) => ['rank' => $index + 1] + $player);
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
