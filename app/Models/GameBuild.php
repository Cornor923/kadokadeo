<?php

namespace App\Models;

use App\Settings\SiteSettings;
use App\Support\GameBuilds\GameBuildArchive;
use Illuminate\Database\Eloquent\Model;

/**
 * A version of the bundle of a game (hash of public/gamesdata/manifest.json): the one a run was played with, so that
 * its replay is played by the same code (app/Support/GameBuilds/GameBuildArchive.php).
 */
class GameBuild extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = ['game_id', 'hash'];

    public function game()
    {
        return $this->belongsTo(Game::class);
    }

    public function runs()
    {
        return $this->hasMany(Run::class);
    }

    /** the version a run begins with, sent by the game (only the current bundle or a version of the archive) */
    public static function resolve(Game $game, ?string $hash): ?self
    {
        if (!app(SiteSettings::class)->game_builds_enabled || $hash === null || !preg_match('/^[0-9a-f]{12}$/', $hash)) {
            return null;
        }
        $current = $game->gamedata['hash'] ?? null;
        if ($hash !== $current && !app(GameBuildArchive::class)->has($game->game_key, $hash)) {
            return null;
        }

        return self::firstOrCreate(['game_id' => $game->id, 'hash' => $hash]);
    }
}
