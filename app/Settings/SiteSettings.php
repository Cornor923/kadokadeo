<?php

namespace App\Settings;

use Illuminate\Support\Str;
use Spatie\LaravelSettings\Settings;

class SiteSettings extends Settings
{
    public bool $announcement_enabled;

    public string $announcement_level;

    public ?string $announcement_content;

    // kado points of the players with the most feathers of a period (shared between the tied ones)
    public int $poids_plume_jackpot;

    // kado points shared equally between the other players with at least 2 feathers
    public int $poids_plume_shared_pool;

    // the games of a player each day (users.kado_games, App\Console\Commands\ResetDailyGames). -1: unlimited
    public int $games_per_day;

    // the games a player can play in parallel; a run not finished after runs_open_minutes no longer counts (a tab closed
    // during a game sends nothing: the runs left open would refuse every new run)
    public int $runs_max_concurrency;

    public int $runs_open_minutes;

    // off: nothing is evaluated on runs / league changes and nothing is shown to players (the admin stays available)
    public bool $achievements_enabled;

    // versions of the game bundles kept for their replays (App\Support\GameBuilds\GameBuildArchive, written by
    // resources/js/games/build-games.mjs). Off: runs remember no version and every replay is played by the current bundle
    // (the production wipes storage/ at each deploy: the archive is lost)
    public bool $game_builds_enabled;

    // the price in Kado points of the themes of config kado.themes: [key => price] ("base" is free)
    public array $theme_prices;

    public static function group(): string
    {
        return 'site';
    }

    // the price of a theme of config kado.themes, -1 when there is no such theme
    public function themePrice(string $key): int
    {
        $theme = config("kado.themes.{$key}");
        if (!is_array($theme)) {
            return -1;
        }
        if ($key === 'base') {
            return 0;
        }

        return max(0, (int) ($this->theme_prices[$key] ?? $theme['price']));
    }

    /**
     * Announcement displayed on every page, or null when there is nothing to display.
     *
     * @return array{level: string, html: string}|null
     */
    public function announcement(): ?array
    {
        if (!$this->announcement_enabled || blank($this->announcement_content)) {
            return null;
        }

        return [
            'level' => $this->announcement_level,
            // Inline markdown only (bold, italic, links): the front renders it inside a <p>.
            // Raw HTML is stripped so the result is safe to inject with v-html.
            'html' => Str::inlineMarkdown(trim($this->announcement_content), [
                'html_input' => 'strip',
                'allow_unsafe_links' => false,
                'renderer' => ['soft_break' => "<br />\n"],
            ]),
        ];
    }
}
