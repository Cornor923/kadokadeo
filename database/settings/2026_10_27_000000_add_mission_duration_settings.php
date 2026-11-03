<?php

use Illuminate\Support\Facades\Artisan;
use Spatie\LaravelSettings\Migrations\SettingsMigration;

// the time of a mission goes down with each mission completed in the period, down to a minimum
// (App\Services\ClanMissionService::missionMinutes)
return new class() extends SettingsMigration
{
    public function up(): void
    {
        $this->migrator->add('clans.mission_minutes_less', 10);
        $this->migrator->add('clans.mission_min_minutes', 720);
        Artisan::call('settings:clear-cache');
    }

    public function down(): void
    {
        $this->migrator->delete('clans.mission_minutes_less');
        $this->migrator->delete('clans.mission_min_minutes');
    }
};
