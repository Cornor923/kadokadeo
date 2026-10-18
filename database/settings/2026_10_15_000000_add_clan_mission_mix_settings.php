<?php

use Spatie\LaravelSettings\Migrations\SettingsMigration;

// the missions mix easy and hard steps, and go beyond the last star (App\Services\ClanMissionPaliers)
return new class() extends SettingsMigration
{
    public function up(): void
    {
        $this->migrator->add('clans.mission_hard_share_min', 0.2);
        $this->migrator->add('clans.mission_hard_share_step', 0.05);
        $this->migrator->add('clans.mission_hard_share_max', 0.5);
        $this->migrator->add('clans.mission_easy_steps', 1);
        $this->migrator->add('clans.mission_spread_paliers', 3);
        $this->migrator->add('clans.mission_beyond_last_star', 0.1);
    }

    public function down(): void
    {
        foreach (['mission_hard_share_min', 'mission_hard_share_step', 'mission_hard_share_max', 'mission_easy_steps', 'mission_spread_paliers', 'mission_beyond_last_star'] as $name) {
            $this->migrator->delete("clans.{$name}");
        }
    }
};
