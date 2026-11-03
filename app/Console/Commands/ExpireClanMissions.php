<?php

namespace App\Console\Commands;

use App\Models\Clan;
use App\Models\ClanMission;
use App\Services\ClanMissionService;
use App\Services\ClanService;
use Illuminate\Console\Command;

class ExpireClanMissions extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'kado:clans:expire-missions';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Fails the clan missions not finished in time: their members are told a new mission is available (it is made when one of them opens the missions).';

    /**
     * Execute the console command.
     */
    public function handle(ClanService $clanService, ClanMissionService $missionService)
    {
        $period = $clanService->currentPeriod();
        if (!$period) {
            return 0;
        }

        $clanIds = ClanMission::query()
            ->where('period_id', $period->id)
            ->where('status', ClanMission::ACTIVE)
            ->where('expires_at', '<=', now())
            ->distinct()
            ->pluck('clan_id');
        foreach (Clan::query()->whereKey($clanIds)->get() as $clan) {
            $missionService->failExpired($clan, $period);
        }
        $this->info($clanIds->count().' clan mission(s) failed.');

        return 0;
    }
}
