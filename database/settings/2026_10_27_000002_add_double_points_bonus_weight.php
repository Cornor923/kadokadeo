<?php

use Illuminate\Support\Facades\Artisan;
use Spatie\LaravelSettings\Migrations\SettingsMigration;

// the "Double points" option of the missions, won as often as "Mission suivante"
return new class() extends SettingsMigration
{
    public function up(): void
    {
        $this->migrator->update('clans.bonus_weights', fn ($weights) => [...(array) $weights, 'double_points' => 20]);
        Artisan::call('settings:clear-cache');
    }

    public function down(): void
    {
        $this->migrator->update('clans.bonus_weights', fn ($weights) => array_diff_key((array) $weights, ['double_points' => true]));
    }
};
