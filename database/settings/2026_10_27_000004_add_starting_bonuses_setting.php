<?php

use Illuminate\Support\Facades\Artisan;
use Spatie\LaravelSettings\Migrations\SettingsMigration;

// the options given to every clan at the start of the period, set in the admin (a "Jeu cool" and a "Jeu caca" until now)
return new class() extends SettingsMigration
{
    public function up(): void
    {
        $this->migrator->add('clans.starting_bonuses', [
            'more_time' => 0, 'ban_game' => 1, 'force_game' => 1, 'next_mission' => 0, 'skip_step' => 0, 'double_points' => 0,
        ]);
        Artisan::call('settings:clear-cache');
    }

    public function down(): void
    {
        $this->migrator->delete('clans.starting_bonuses');
    }
};
