<?php

namespace App\Providers;

use App\Achievements\AchievementRule;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Database\Events\MigrationsEnded;
use Illuminate\Database\Events\NoPendingMigrations;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\ServiceProvider;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use ReflectionClass;
use SplFileInfo;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->tag($this->achievementRules(), 'achievement.rules');

        $this->app->bind(\App\Services\RunService::class, fn () => new \App\Services\RunService(config('kado.security')));
        $this->app->bind(\App\Services\GameService::class, fn () => new \App\Services\GameService());
        $this->app->bind(\App\Services\ScoreService::class, fn () => new \App\Services\ScoreService());
        $this->app->bind(\App\Services\PeriodService::class, fn () => new \App\Services\PeriodService());
        $this->app->bind(\App\Services\AchievementService::class, fn ($app) => new \App\Services\AchievementService($app->tagged('achievement.rules')));
        $this->app->bind(\App\Services\LeagueService::class, fn ($app) => new \App\Services\LeagueService($app->make(\App\Services\ScoreService::class), $app->make(\App\Services\AchievementService::class)));
        $this->app->bind(\App\Services\PoidsPlumeService::class, fn ($app) => new \App\Services\PoidsPlumeService(
            $app->make(\App\Services\LeagueService::class),
            $app->make(\App\Services\ScoreService::class)
        ));
    }

    private function achievementRules(): array
    {
        $rulesPath = app_path('Achievements/Rules');
        if (!is_dir($rulesPath)) {
            return [];
        }

        $rules = [];
        $files = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($rulesPath));
        foreach ($files as $file) {
            if (!$file instanceof SplFileInfo || $file->getExtension() !== 'php') {
                continue;
            }

            $relativePath = str_replace($rulesPath.DIRECTORY_SEPARATOR, '', $file->getPathname());
            $class = 'App\\Achievements\\Rules\\'.str_replace(['/', '\\', '.php'], ['\\', '\\', ''], $relativePath);
            if (!class_exists($class)) {
                continue;
            }

            $reflection = new ReflectionClass($class);
            if (!$reflection->isInstantiable() || !$reflection->implementsInterface(AchievementRule::class)) {
                continue;
            }

            $rules[] = $class;
        }

        sort($rules);

        return $rules;
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // the contents the players can report (App\Contracts\Reportable): reports.reportable_type keeps these aliases. Not
        // enforced: the other morph relations (tokens of Sanctum) keep their class names.
        Relation::morphMap([
            'run_comment' => \App\Models\RunComment::class,
        ]);

        // the settings cache (SETTINGS_CACHE_ENABLED) keeps serialized settings objects: a property added by a settings
        // migration stays uninitialized in them ("must not be accessed before initialization"), so every `migrate` clears it
        // (also with nothing to migrate, for a deployment whose migrations already ran)
        Event::listen([MigrationsEnded::class, NoPendingMigrations::class], function () {
            if (config('settings.cache.enabled')) {
                app(\Spatie\LaravelSettings\SettingsCache::class)->clear();
            }
        });
    }
}
