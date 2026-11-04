<?php

namespace App\Models;

use App\Support\UserAgent;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * A session of the site (SESSION_DRIVER=database, the table of Laravel): the browser of a player logged in (the SPA
 * and the games are authenticated by it). Read by the admin (UserResource, tab « Sessions »), written by Laravel only.
 *
 * @property string $id
 * @property int|null $user_id
 * @property string|null $ip_address
 * @property string|null $user_agent
 * @property int $last_activity
 */
class Session extends Model
{
    public $incrementing = false;

    public $timestamps = false;

    protected $keyType = 'string';

    // (its payload holds the CSRF token of the session: never shown)
    protected $hidden = ['payload'];

    /**
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function lastActivityAt(): Carbon
    {
        return Carbon::createFromTimestamp($this->last_activity);
    }

    // still usable: active within the lifetime of the sessions (SESSION_LIFETIME; « remember me » opens a new one after)
    public function isActive(): bool
    {
        return $this->last_activity >= now()->subMinutes((int) config('session.lifetime'))->getTimestamp();
    }

    // "Firefox · Windows", from the user agent (the main browsers and systems only)
    public function device(): string
    {
        $agent = new UserAgent((string) $this->user_agent);

        return implode(' · ', array_filter([$agent->browser(), $agent->system()])) ?: 'Inconnu';
    }
}
