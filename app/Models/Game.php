<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;

class Game extends Model
{
    use HasFactory;

    public const GAMES_MANIFEST_CACHE_KEY = 'gamesdata_manifest';

    protected $fillable = ['name', 'description', 'category_id', 'image_path', 'stars', 'is_active', 'is_arkadeo', 'score_rankv1'];

    protected $casts = [
        'stars' => 'json',
        'score_rankv1' => 'integer',
    ];

    protected $with = ['category'];

    public function getGamedataAttribute()
    {
        $fileName = $this->game_key.'.js';
        $file = '/gamesdata/'.$fileName;
        $filePath = public_path(ltrim($file, '/'));
        if (!file_exists($filePath)) {
            return null;
        }

        $manifest = self::getGamesManifest();
        $manifestEntry = $manifest[$fileName] ?? null;
        $hash = is_array($manifestEntry) ? ($manifestEntry['hash'] ?? null) : null;
        $size = is_array($manifestEntry) ? ($manifestEntry['size'] ?? null) : null;

        if (!is_int($size)) {
            $size = filesize($filePath);
        }

        $url = $file;
        if (is_string($hash) && $hash !== '') {
            $url .= '?v='.$hash;
        }

        return [
            'file' => $file,
            'size' => $size,
            'hash' => $hash,
            'url' => $url,
            // an ES module, loaded with import() (resources/js/games/builds/bundle.mjs), or a classic script
            'module' => is_array($manifestEntry) && ($manifestEntry['format'] ?? null) === 'esm',
        ];
    }

    private static function getGamesManifest(): array
    {
        $manifestPath = public_path('gamesdata/manifest.json');
        if (!file_exists($manifestPath)) {
            return [];
        }

        $manifestMtime = filemtime($manifestPath);
        if ($manifestMtime === false) {
            return [];
        }

        $cachedManifest = Cache::get(self::GAMES_MANIFEST_CACHE_KEY);
        if (
            is_array($cachedManifest)
            && ($cachedManifest['mtime'] ?? null) === $manifestMtime
            && is_array($cachedManifest['data'] ?? null)
        ) {
            return $cachedManifest['data'];
        }

        $manifestContent = file_get_contents($manifestPath);
        if (!is_string($manifestContent)) {
            return [];
        }

        $decodedManifest = json_decode($manifestContent, true);
        if (!is_array($decodedManifest)) {
            return [];
        }

        Cache::put(self::GAMES_MANIFEST_CACHE_KEY, [
            'mtime' => $manifestMtime,
            'data' => $decodedManifest,
        ], now()->addMinutes(15));

        return $decodedManifest;
    }

    public function getPascalNameAttribute(): string
    {
        // (accents dropped first: "Chakré Bouddha" -> GameChakreBouddha)
        return Str::of('Game'.$this->name)->ascii()->pascal()->replaceMatches('/[^a-zA-Z0-9]/', '')->toString();
    }

    public function getGameKeyAttribute(): string
    {
        // (accents dropped first: "Chakré Bouddha" -> chakrebouddha)
        return Str::of($this->name)->ascii()->lower()->replaceMatches('/[^a-z0-9]/', '')->toString();
    }

    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    public function runs()
    {
        return $this->hasMany(Run::class);
    }

    public function leagueMemberships()
    {
        return $this->hasMany(LeagueMembership::class);
    }

    public function leaguePromotions()
    {
        return $this->hasMany(LeaguePromotion::class);
    }

    public function dailyGames()
    {
        return $this->hasMany(DailyGame::class);
    }

    public function controls()
    {
        return $this->hasMany(GameControl::class)
            ->orderBy('order');
    }

    public function periodStars()
    {
        return $this->hasMany(GamePeriodStar::class);
    }

    public function achievements()
    {
        return $this->hasMany(Achievement::class);
    }

    public function getStarFromScore(int $score): int
    {
        $gainedStar = -1;
        foreach (($this->stars ?? []) as $index => $threshold) {
            if ($score >= $threshold) {
                $gainedStar = $index;
            }
        }

        return $gainedStar;
    }
}
