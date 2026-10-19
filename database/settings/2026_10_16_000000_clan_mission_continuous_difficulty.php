<?php

use Illuminate\Support\Facades\Artisan;
use Spatie\LaravelSettings\Migrations\SettingsMigration;

// the difficulty of the steps of the missions in stars, without paliers (App\Services\ClanMissionPaliers): the other steps
// are spread on all the difficulties, the easy ones come by themselves
return new class() extends SettingsMigration
{
    public function up(): void
    {
        // as before: half a star every 2 missions
        $this->migrator->add('clans.mission_stars_per_mission', 0.25);
        // by mission instead of by palier of 2 missions
        $this->migrator->update('clans.mission_hard_share_step', fn ($step) => $step / 2);
        $this->migrator->delete('clans.mission_paliers_every');
        $this->migrator->delete('clans.mission_easy_steps');
        $this->migrator->delete('clans.mission_spread_paliers');
        Artisan::call('settings:clear-cache');
    }

    public function down(): void
    {
        $this->migrator->add('clans.mission_paliers_every', 2);
        $this->migrator->add('clans.mission_easy_steps', 1);
        $this->migrator->add('clans.mission_spread_paliers', 3);
        $this->migrator->update('clans.mission_hard_share_step', fn ($step) => $step * 2);
        $this->migrator->delete('clans.mission_stars_per_mission');
    }
};
