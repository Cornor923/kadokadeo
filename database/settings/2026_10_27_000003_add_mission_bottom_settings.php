<?php

use Illuminate\Support\Facades\Artisan;
use Spatie\LaravelSettings\Migrations\SettingsMigration;

// the easiest steps of the missions get harder with each mission, from half the green star up to a maximum
// (App\Services\ClanMissionPaliers::bottomDifficulty)
return new class() extends SettingsMigration
{
    public function up(): void
    {
        $this->migrator->add('clans.mission_bottom_per_mission', 0.025);
        $this->migrator->add('clans.mission_bottom_max', 0.75);
        Artisan::call('settings:clear-cache');
    }

    public function down(): void
    {
        $this->migrator->delete('clans.mission_bottom_per_mission');
        $this->migrator->delete('clans.mission_bottom_max');
    }
};
