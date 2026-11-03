<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;

use App\Enums\BanReason;
use App\Enums\UserPreference;
use App\Events\UserCountersChanged;
use App\Settings\SiteSettings;
use App\Support\Realtime;
use Filament\Models\Contracts\FilamentUser;
use Filament\Panel;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Str;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable implements FilamentUser
{
    /** @use HasFactory<\Database\Factories\UserFactory> */
    use HasApiTokens;

    use HasFactory;
    use Notifiable;

    protected $hidden = [
        'password',
        'etwin_access_token',
        'etwin_scopes',
    ];

    protected $guarded = [
        // 'password',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'last_seen_at' => 'datetime',
            'password' => 'hashed',
            'banned_at' => 'datetime',
            'ban_reason' => BanReason::class,
            'unlocked_themes' => 'array',
            // App\Enums\UserPreference => bool (missing: its default)
            'preferences' => 'array',
            // the access token of Eternaltwin (its forum is called as the player) and what it allows
            'etwin_access_token' => 'encrypted',
            'etwin_scopes' => 'array',
        ];
    }

    // his Kado points and games changed through the model: his menus at once (the writes by query call Realtime themselves)
    protected static function booted(): void
    {
        static::updated(function (User $user) {
            if ($user->wasChanged(UserCountersChanged::COUNTERS)) {
                Realtime::send(new UserCountersChanged($user->id));
            }
        });
    }

    // the token of Eternaltwin may write in its forum (scope forum:write, App\Http\Controllers\Api\EtwinForumController)
    public function canWriteEtwinForum(): bool
    {
        return $this->etwin_access_token !== null && ($this->etwin_scopes['forum_write'] ?? false) === true;
    }

    public function userPoints()
    {
        return $this->hasMany(UserPoint::class);
    }

    public function runs()
    {
        return $this->hasMany(Run::class);
    }

    public function gamePeriodStars()
    {
        return $this->hasMany(GamePeriodStar::class);
    }

    public function stars()
    {
        return $this->hasMany(UserStar::class);
    }

    public function leagueMemberships()
    {
        return $this->hasMany(LeagueMembership::class);
    }

    public function leaguePromotions()
    {
        return $this->hasMany(LeaguePromotion::class);
    }

    public function poidsPlumeResults()
    {
        return $this->hasMany(PoidsPlumeResult::class);
    }

    // the sessions of the site where the player is logged in (their browsers)
    public function sessions()
    {
        return $this->hasMany(Session::class);
    }

    // logs the player out of all their browsers: the sessions, the cookie « remember me » (one token for all the browsers:
    // a new one), the tokens of the pages opened before the session cookies
    public function logOutEverywhere(): void
    {
        $this->sessions()->delete();
        $this->setRememberToken(Str::random(60));
        $this->save();
        $this->tokens()->delete();
    }

    public function achievementProgress()
    {
        return $this->hasMany(UserAchievementProgress::class);
    }

    public function favorite()
    {
        return $this->hasMany(UserFavoriteGame::class);
    }

    public function clanMember()
    {
        return $this->hasOne(ClanMember::class);
    }

    // the themes of the site he can use (kado.themes): the free ones and the ones he bought
    public function hasTheme(string $theme): bool
    {
        return app(SiteSettings::class)->themePrice($theme) === 0 || in_array($theme, $this->unlocked_themes ?? [], true);
    }

    public function prefers(UserPreference $preference): bool
    {
        /** @var array<string, bool> $preferences */
        $preferences = $this->preferences ?? [];

        return (bool) ($preferences[$preference->value] ?? $preference->default());
    }

    /** @return array<string, bool> every preference, set or not */
    public function preferenceValues(): array
    {
        $values = [];
        foreach (UserPreference::cases() as $preference) {
            $values[$preference->value] = $this->prefers($preference);
        }

        return $values;
    }

    //

    public function canAccessPanel(Panel $panel): bool
    {
        return $this->is_admin && !$this->isBanned();
    }

    public function isBanned(): bool
    {
        return $this->banned_at !== null;
    }

    public function banMessage(): string
    {
        return $this->ban_reason?->message() ?? 'Votre compte a été banni.';
    }

    // players log in with Eternaltwin and have no password, but Laravel compares it (as a string) with the hash
    // in the "remember me" cookie, still held by those who logged in when the OAuth callback was a web route
    public function getAuthPassword(): string
    {
        return $this->password ?? '';
    }

    public function getNameAttribute(): string
    {
        return $this->display_name;
    }
}
