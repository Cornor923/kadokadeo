<?php

use Illuminate\Support\Facades\Artisan;
use Spatie\LaravelSettings\Migrations\SettingsMigration;

// the games of the players, the achievements, the game builds and the price of the themes, read from the env until now
// (config/kado.php): the env gives their first values
return new class() extends SettingsMigration
{
    public function up(): void
    {
        $this->migrator->add('site.games_per_day', (int) (config('kado.legacy.games_per_day') ?? 100));
        $this->migrator->add('site.runs_max_concurrency', (int) (config('kado.legacy.runs_max_concurrency') ?? 50));
        $this->migrator->add('site.runs_open_minutes', (int) (config('kado.legacy.runs_open_minutes') ?? 120));
        $this->migrator->add('site.achievements_enabled', (bool) (config('kado.legacy.achievements_enabled') ?? false));
        $this->migrator->add('site.game_builds_enabled', (bool) (config('kado.legacy.game_builds_enabled') ?? false));
        $this->migrator->add('site.theme_prices', ['karbon' => (int) (config('kado.legacy.theme_karbon_price') ?? 10000)]);
        Artisan::call('settings:clear-cache');
    }

    public function down(): void
    {
        foreach (['games_per_day', 'runs_max_concurrency', 'runs_open_minutes', 'achievements_enabled', 'game_builds_enabled', 'theme_prices'] as $name) {
            $this->migrator->delete("site.{$name}");
        }
    }
};
