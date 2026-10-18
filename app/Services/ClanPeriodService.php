<?php

namespace App\Services;

use App\Models\Clan;
use App\Models\ClanMember;
use App\Models\ClanMemberStat;
use App\Models\ClanMission;
use App\Models\ClanPeriodScore;
use App\Models\Period;
use App\Settings\ClanSettings;
use Illuminate\Support\Facades\DB;

// the end of the tournament of the clans (App\Console\Commands\PrepareNewPeriod): the clans are ranked by their attack
// score and by their mission score, the best ones win Kado points shared equally between their members
class ClanPeriodService
{
    public function __construct(
        private readonly ClanService $clanService,
        private readonly ClanWarService $warService,
        private readonly ClanMissionService $missionService,
    ) {}

    // can be called again (PrepareNewPeriod closes the previous period on the next Monday too): a clan is paid once
    public function closePeriod(Period $period): void
    {
        $this->warService->resolveExpired();
        $this->warService->cancelUnfinished($period);
        $this->warService->endWarsOf($period);
        app(ClanRunService::class)->cancelUnfinished($period);

        // a mission not finished at the end of the period is failed: its points are lost
        $missions = ClanMission::query()->where('period_id', $period->id)->where('status', ClanMission::ACTIVE)->get();
        foreach ($missions as $mission) {
            $this->missionService->loseMission($mission, ClanMission::FAILED);
        }

        $this->rank($period, 'war_score', 'war_rank');
        $this->rank($period, 'mission_score', 'mission_rank');

        $scores = ClanPeriodScore::query()->where('period_id', $period->id)->whereNull('closed_at')->get();
        foreach ($scores as $score) {
            DB::transaction(fn () => $this->reward($score, $period));
        }
    }

    public function rewardForRank(?int $rank, string $ranking): int
    {
        if (!$rank) {
            return 0;
        }

        foreach (app(ClanSettings::class)->rewards($ranking) as $lastRank => $points) {
            if ($rank <= $lastRank) {
                return (int) $points;
            }
        }

        return 0;
    }

    // only the clans that scored are ranked
    private function rank(Period $period, string $column, string $rankColumn): void
    {
        $ids = ClanPeriodScore::query()
            ->where('period_id', $period->id)
            ->where($column, '>', 0)
            ->orderByDesc($column)
            ->orderBy('clan_id')
            ->pluck('id');

        foreach ($ids as $index => $id) {
            ClanPeriodScore::query()->whereKey($id)->update([$rankColumn => $index + 1]);
        }
    }

    private function reward(ClanPeriodScore $score, Period $period): void
    {
        $score->refresh();
        $total = $this->rewardForRank($score->war_rank, 'war') + $this->rewardForRank($score->mission_rank, 'missions');
        $clan = Clan::query()->find($score->clan_id);
        $memberIds = $clan ? ClanMember::query()->where('clan_id', $clan->id)->pluck('user_id') : collect();
        $share = $memberIds->isNotEmpty() ? intdiv($total, $memberIds->count()) : 0;

        foreach ($memberIds as $userId) {
            $stat = $this->clanService->memberStat($clan->id, $userId, $period->id);
            if ($share <= 0 || $stat->user_point_id) {
                continue;
            }

            $user = $stat->user;
            $user->increment('kado_points', $share);
            $userPoint = $user->userPoints()->create([
                'period_id' => $period->id,
                'delta' => $share,
                'reason' => 'clan ranking',
                'source_type' => ClanMemberStat::class,
                'source_id' => $stat->id,
            ]);
            $stat->update(['reward' => $share, 'user_point_id' => $userPoint->id]);
        }

        $score->update(['reward' => $total, 'closed_at' => now()]);
    }
}
