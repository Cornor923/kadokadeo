<?php

namespace App\Services;

use App\Events\UserCountersChanged;
use App\Models\DailyGame;
use App\Models\DailyRankingResult;
use App\Models\Period;
use App\Models\User;
use App\Settings\SiteSettings;
use App\Support\Realtime;
use Carbon\CarbonInterface;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Spatie\DiscordAlerts\Facades\DiscordAlert;

/**
 * The ranking of the daily game over a period: each day its top 10 gets points (10 for the 1st, 1 for the 10th). The
 * period closed, each player with points gets daily_ranking_kado_per_point Kado points by point, and the top goes on
 * Discord. The ranking is read from the runs until then, the results are not changed afterwards (a run found to be a
 * cheat later takes nothing back, as for the feathers and the leagues), and the runs not finished by the end of the
 * period are refused.
 */
class DailyRankingService
{
    // the points of the 1st of a day, and the positions that get points
    public const TOP = 10;

    private const DISCORD_MAX_LENGTH = 2000;

    private const CURRENT_STANDINGS_SECONDS = 60;

    public function __construct(private readonly ScoreService $scoreService) {}

    public static function pointsForPosition(int $position): int
    {
        return max(0, self::TOP + 1 - $position);
    }

    // from daily_games.day: runs.period_id is null for the runs started during the close of a period
    public function periodOfDay(CarbonInterface $day): ?Period
    {
        return Period::query()
            ->where('start_at', '<=', $day->copy()->endOfDay())
            ->where('end_at', '>=', $day->copy()->startOfDay())
            ->orderByDesc('id')
            ->first();
    }

    // the period of the day of this game is over: its ranking is frozen, or about to be
    public function isClosed(DailyGame $dailyGame): bool
    {
        return (bool) $this->periodOfDay($dailyGame->day)?->end_at->isPast();
    }

    /**
     * The ranking of the current period for the pages, without the ids of the players (nothing during the close of a
     * period). Asked by every page open on the daily game when its scores change: kept until they change.
     *
     * @return array<int, array<string, mixed>>
     */
    public function currentStandings(): array
    {
        $period = $this->periodOfDay(today());
        if (!$period) {
            return [];
        }

        return Cache::remember(
            $this->currentStandingsKey(),
            self::CURRENT_STANDINGS_SECONDS,
            fn () => $this->standings($period)->map(fn (array $player) => Arr::except($player, 'user_id'))->all(),
        );
    }

    public function forgetCurrentStandings(): void
    {
        Cache::forget($this->currentStandingsKey());
    }

    private function currentStandingsKey(): string
    {
        return 'daily_standings_'.today()->toDateString();
    }

    /**
     * The players with points: most points first, then most days won. Same points, same rank, without gaps (1, 1, 2).
     *
     * @return Collection<int, array{points: int, wins: int, user_id: int, user: array{etwin_id: string, display_name: string}, rank: int}>
     */
    public function standings(Period $period): Collection
    {
        $dailyGameIds = DailyGame::query()
            ->whereBetween('day', [$period->start_at->copy()->startOfDay(), $period->end_at->copy()->endOfDay()])
            ->pluck('id')
            ->all();

        if ($dailyGameIds === []) {
            return collect();
        }

        $positionsByUser = $this->scoreService->rankedDailyRuns($dailyGameIds)
            ->where('rank_position', '<=', self::TOP)
            ->get(['user_id', 'rank_position'])
            ->groupBy('user_id');
        $users = User::query()->whereIn('id', $positionsByUser->keys())->get(['id', 'etwin_id', 'display_name'])->keyBy('id');

        $players = $positionsByUser
            ->filter(fn (Collection $positions, int $userId) => $users->has($userId))
            ->map(fn (Collection $positions, int $userId) => [
                'points' => (int) $positions->sum(fn ($run) => self::pointsForPosition($run->rank_position)),
                'wins' => $positions->where('rank_position', 1)->count(),
                'user_id' => $userId,
                'user' => [
                    'etwin_id' => $users[$userId]->etwin_id,
                    'display_name' => $users[$userId]->display_name,
                ],
            ])
            ->sort(fn (array $left, array $right) => ($right['points'] <=> $left['points'])
                ?: ($right['wins'] <=> $left['wins'])
                ?: strcasecmp($left['user']['display_name'], $right['user']['display_name']))
            ->values();

        $rankOfPoints = $players->pluck('points')->unique()->values()->flip();

        return $players->map(fn (array $player) => ['rank' => $rankOfPoints[$player['points']] + 1] + $player);
    }

    public function closePeriod(Period $period): void
    {
        if ($period->dailyRankingResults()->exists()) {
            return;
        }

        $standings = $this->standings($period);
        if ($standings->isEmpty()) {
            return;
        }

        $kadoPerPoint = max(0, app(SiteSettings::class)->daily_ranking_kado_per_point);
        $paidUserIds = [];

        DB::transaction(function () use ($period, $standings, $kadoPerPoint, &$paidUserIds) {
            foreach ($standings as $player) {
                $result = DailyRankingResult::query()->create([
                    'period_id' => $period->id,
                    'user_id' => $player['user_id'],
                    'rank_position' => $player['rank'],
                    'points' => $player['points'],
                    'reward' => $player['points'] * $kadoPerPoint,
                ]);

                if ($result->reward <= 0) {
                    continue;
                }

                $user = $result->user;
                $user->increment('kado_points', $result->reward);

                // (never the run as a source: taking a run back takes back every point it brought)
                $userPoint = $user->userPoints()->create([
                    'period_id' => $period->id,
                    'delta' => $result->reward,
                    'reason' => 'daily ranking',
                    'source_type' => DailyRankingResult::class,
                    'source_id' => $result->id,
                ]);

                $result->user_point_id = $userPoint->id;
                $result->save();
                $paidUserIds[] = $user->id;
            }
        });

        foreach ($paidUserIds as $userId) {
            Realtime::send(new UserCountersChanged($userId));
        }

        if (config('discord-alerts.webhook_urls.scores')) {
            DiscordAlert::to('scores')->message($this->discordMessage($period, $standings));
        }
    }

    private function discordMessage(Period $period, Collection $standings): string
    {
        $message = "🏁 **Jeu du jour — classement final, période du {$period->start_at->format('d/m')} au {$period->end_at->format('d/m')}**";

        // (more than 10 lines with tied players: the 10 best totals)
        foreach ($standings->where('rank', '<=', self::TOP) as $player) {
            $place = match ($player['rank']) {
                1 => ':first_place:',
                2 => ':second_place:',
                3 => ':third_place:',
                default => "{$player['rank']}.",
            };
            $line = "\n{$place} **{$this->discordName($player['user']['display_name'])}** : {$player['points']} pts";

            if (mb_strlen($message.$line) > self::DISCORD_MAX_LENGTH) {
                break;
            }
            $message .= $line;
        }

        return $message;
    }

    // the name of a player, chosen by them: no Markdown, no link, no emoji, no mention (a webhook can ping @everyone)
    private function discordName(string $name): string
    {
        return str_replace('@', "@\u{200B}", preg_replace('/([\\\\*_~`|<>\[\]():])/', '\\\\$1', $name));
    }
}
