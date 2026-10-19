<?php

use Illuminate\Support\Facades\Artisan;
use Spatie\LaravelSettings\Migrations\SettingsMigration;

// the clans can be turned off (App\Http\Middleware\EnsureClansAreEnabled): off until they open
return new class() extends SettingsMigration
{
    public function up(): void
    {
        $this->migrator->add('clans.enabled', false);
        Artisan::call('settings:clear-cache');
    }

    public function down(): void
    {
        $this->migrator->delete('clans.enabled');
    }
};
