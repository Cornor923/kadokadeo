<?php

use Illuminate\Support\Facades\Artisan;
use Spatie\LaravelSettings\Migrations\SettingsMigration;

// the Kado points paid to create a clan and for each application to a clan (given back when it is refused or cancelled)
return new class() extends SettingsMigration
{
    public function up(): void
    {
        $this->migrator->add('clans.creation_price', 5000);
        $this->migrator->add('clans.application_price', 100);
        Artisan::call('settings:clear-cache');
    }

    public function down(): void
    {
        $this->migrator->delete('clans.creation_price');
        $this->migrator->delete('clans.application_price');
    }
};
