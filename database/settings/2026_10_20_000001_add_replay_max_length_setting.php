<?php

use Illuminate\Support\Facades\Artisan;
use Spatie\LaravelSettings\Migrations\SettingsMigration;

// the longest replay sent at the end of a run, read from the env until now (config kado.legacy)
return new class() extends SettingsMigration
{
    public function up(): void
    {
        $this->migrator->add('replays.max_length', (int) (config('kado.legacy.replay_max_length') ?? 10_000_000));
        Artisan::call('settings:clear-cache');
    }

    public function down(): void
    {
        $this->migrator->delete('replays.max_length');
    }
};
