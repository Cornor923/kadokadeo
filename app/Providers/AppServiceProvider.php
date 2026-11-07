<?php

namespace App\Providers;

use App\Achievements\AchievementRule;
use App\Events\AnnouncementUpdated;
use App\Models\PersonalAccessToken;
use App\Models\RunComment;
use App\Services\AchievementService;
use App\Services\GameService;
use App\Services\LeagueService;
use App\Services\PeriodService;
use App\Services\PoidsPlumeService;
use App\Services\RunService;
use App\Services\ScoreService;
use App\Settings\SiteSettings;
use App\Support\Realtime;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Database\Events\MigrationsEnded;
use Illuminate\Database\Events\NoPendingMigrations;
use Illuminate\Http\Middleware\TrustProxies;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\ServiceProvider;
use Laravel\Sanctum\Sanctum;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use ReflectionClass;
use Spatie\LaravelSettings\Events\SettingsSaved;
use Spatie\LaravelSettings\SettingsCache;
use SplFileInfo;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->bind(RunService::class, fn () => new RunService(config('kado.security')));
        $this->app->bind(GameService::class, fn () => new GameService());
        $this->app->bind(ScoreService::class, fn () => new ScoreService());
        $this->app->bind(PeriodService::class, fn () => new PeriodService());
        $this->app->bind(AchievementService::class, fn ($app) => new AchievementService(
            // (when a run ends: most requests read no rule)
            fn () => array_map(fn (string $rule) => $app->make($rule), $this->achievementRules()),
        ));
        $this->app->bind(LeagueService::class, fn ($app) => new LeagueService($app->make(ScoreService::class), $app->make(AchievementService::class)));
        $this->app->bind(PoidsPlumeService::class, fn ($app) => new PoidsPlumeService(
            $app->make(LeagueService::class),
            $app->make(ScoreService::class)
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
            'run_comment' => RunComment::class,
        ]);

        // last_used_at written every 5 minutes, not at each request
        Sanctum::usePersonalAccessTokenModel(PersonalAccessToken::class);

        // only the IP: the host and the scheme of the URLs stay the ones of the server
        if ($proxies = config('kado.trusted_proxies')) {
            TrustProxies::at($proxies);
            TrustProxies::withHeaders(Request::HEADER_X_FORWARDED_FOR);
        }

        // the settings cache (SETTINGS_CACHE_ENABLED) keeps serialized settings objects: a property added by a settings
        // migration stays uninitialized in them ("must not be accessed before initialization"), so every `migrate` clears it
        // (also with nothing to migrate, for a deployment whose migrations already ran)
        Event::listen([MigrationsEnded::class, NoPendingMigrations::class], function () {
            if (config('settings.cache.enabled')) {
                app(SettingsCache::class)->clear();
            }
        });

        // the announcement saved in the admin (« Paramètres > Site »): the banner of the pages open changes at once
        Event::listen(SettingsSaved::class, function (SettingsSaved $event) {
            if ($event->settings instanceof SiteSettings) {
                Realtime::send(AnnouncementUpdated::of($event->settings));
            }
        });
    }
}
