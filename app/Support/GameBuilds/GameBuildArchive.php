<?php

namespace App\Support\GameBuilds;

use App\Models\Game;
use App\Models\GameBuild;
use App\Settings\SiteSettings;
use RuntimeException;

/**
 * The versions of the game bundles kept for their replays (written at each build by
 * resources/js/games/builds/archive.mjs into storage/app/game-builds, see its header for the layout).
 *
 * A replay only holds the inputs of the player: it has to be played by the version of the game it was recorded with.
 * A run remembers that version (runs.game_build_id); an old version is rebuilt from the current bundle and a delta
 * of a few hundred bytes, and loads its own spritesheet (frames of today + the frames it lost since).
 */
class GameBuildArchive
{
    private static array $indexCache = [];

    public function __construct(private ?string $path = null, private ?string $publicPath = null)
    {
        $this->path ??= config('kado.game_builds.path', storage_path('app/game-builds'));
        $this->publicPath ??= public_path();
    }

    public function path(string $file = ''): string
    {
        return rtrim($this->path, '/\\').($file === '' ? '' : '/'.$file);
    }

    public function index(): array
    {
        $file = $this->path('index.json');
        $mtime = @filemtime($file);
        if ($mtime === false) {
            return ['games' => []];
        }
        $cached = self::$indexCache[$file] ?? null;
        if ($cached && $cached['mtime'] === $mtime) {
            return $cached['data'];
        }
        $data = json_decode((string) @file_get_contents($file), true);
        if (!is_array($data)) {
            return ['games' => []];
        }
        self::$indexCache[$file] = ['mtime' => $mtime, 'data' => $data];

        return $data;
    }

    public function game(string $key): ?array
    {
        return $this->index()['games'][$key] ?? null;
    }

    /** an old version of a game (not the current one) */
    public function version(string $key, string $hash): ?array
    {
        $version = $this->game($key)['versions'][$hash] ?? null;

        return is_array($version) ? $version : null;
    }

    public function has(string $key, string $hash): bool
    {
        return $this->version($key, $hash) !== null;
    }

    /** the version of the bundles built before the archive existed (runs without a version) */
    public function legacyHash(string $key): ?string
    {
        foreach ($this->game($key)['versions'] ?? [] as $hash => $version) {
            if ($version['legacy'] ?? false) {
                return (string) $hash;
            }
        }

        return null;
    }

    /** the bundle (JS) of an old version, rebuilt from the current bundle; null: unknown version */
    public function bundle(string $key, string $hash): ?string
    {
        $version = $this->version($key, $hash);
        if ($version === null) {
            return null;
        }
        $base = $this->currentBundle($key, (string) $version['base']);
        $delta = @file_get_contents($this->path("{$key}/bundles/{$hash}.{$version['base']}.kdd"));
        if ($base === null) {
            // a build is running: the new bundle is on disk, the index not written yet, but its delta is there
            $file = @file_get_contents(rtrim($this->publicPath, '/\\')."/gamesdata/{$key}.js");
            if ($file !== false) {
                $base = $file;
                $delta = @file_get_contents($this->path("{$key}/bundles/{$hash}.".BundleDelta::hash($file).'.kdd'));
            }
        }
        if ($base === null || $delta === false) {
            throw new RuntimeException("game build: {$key} {$hash} cannot be rebuilt now");
        }

        return BundleDelta::apply($base, $delta);
    }

    private function currentBundle(string $key, string $hash): ?string
    {
        $file = @file_get_contents(rtrim($this->publicPath, '/\\')."/gamesdata/{$key}.js");
        if ($file !== false && BundleDelta::hash($file) === $hash) {
            return $file;
        }
        // public/gamesdata rebuilt or wiped: the copy kept with the archive
        $copy = @file_get_contents($this->path("{$key}/current.js.gz"));
        $copy = $copy === false ? false : @gzdecode($copy);
        if ($copy !== false && BundleDelta::hash($copy) === $hash) {
            return $copy;
        }

        return null;
    }

    /**
     * What a replay of this game has to load: the current bundle, or the old version it was recorded with
     * (gamedata of Game, plus asset_base: the folder of its spritesheet when it is not today's one).
     */
    public function gamedataFor(Game $game, ?GameBuild $build): ?array
    {
        $current = $game->gamedata;
        $key = $game->game_key;
        $hash = app(SiteSettings::class)->game_builds_enabled ? $build?->hash ?? $this->legacyHash($key) : null;
        if ($hash === null || ($current['hash'] ?? null) === $hash) {
            return $current === null ? null : $current + ['asset_base' => null];
        }
        $version = $this->version($key, $hash);
        if ($version === null) {
            // not kept: the replay is played by the bundle of today
            return $current === null ? null : $current + ['asset_base' => null];
        }
        $url = "/gamesdata/builds/{$key}/{$hash}.js";

        return [
            'file' => $url,
            'size' => $version['size'] ?? null,
            'hash' => $hash,
            'url' => $url,
            // the versions built before the ES modules are classic scripts
            'module' => ($version['format'] ?? 'iife') === 'esm',
            'asset_base' => $version['assetBase'] ?? null,
        ];
    }

    /** the versions still used by replays: the build removes the others (storage/app/game-builds/keep.json) */
    public function writeKeep(array $games, array $legacy): void
    {
        if (!is_dir($this->path())) {
            mkdir($this->path(), 0775, true);
        }
        $data = ['generatedAt' => now()->toIso8601String(), 'games' => $games, 'legacy' => $legacy];
        $tmp = $this->path('keep.json.tmp');
        file_put_contents($tmp, json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)."\n");
        rename($tmp, $this->path('keep.json'));
    }
}
