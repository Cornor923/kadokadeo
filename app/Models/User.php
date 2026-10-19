<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;

use App\Enums\BanReason;
use Filament\Models\Contracts\FilamentUser;
use Filament\Panel;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
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
            // the access token of Eternaltwin (its forum is called as the player) and what it allows
            'etwin_access_token' => 'encrypted',
            'etwin_scopes' => 'array',
        ];
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
        return (int) config("kado.themes.{$theme}.price", -1) === 0 || in_array($theme, $this->unlocked_themes ?? [], true);
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
