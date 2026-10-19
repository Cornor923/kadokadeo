<?php

namespace App\Models;

use App\Services\ClanService;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Clan extends Model
{
    use HasFactory;

    protected $fillable = ['name', 'description', 'leader_id', 'is_recruiting', 'clan_games'];

    protected $casts = [
        'is_recruiting' => 'boolean',
        // the paid clan games given by the members, to distribute (App\Services\ClanGameService)
        'clan_games' => 'integer',
    ];

    protected static function booted(): void
    {
        // disbanded (by its leader, its last member leaving or the admin): the applications waiting are paid back before
        // they go with it
        static::deleting(fn (Clan $clan) => app(ClanService::class)->cancelApplicationsOf($clan));
    }

    public function leader()
    {
        return $this->belongsTo(User::class, 'leader_id');
    }

    public function members()
    {
        return $this->hasMany(ClanMember::class);
    }

    public function users()
    {
        return $this->belongsToMany(User::class, 'clan_members')->withTimestamps();
    }

    public function applications()
    {
        return $this->hasMany(ClanApplication::class);
    }

    public function periodScores()
    {
        return $this->hasMany(ClanPeriodScore::class);
    }

    public function memberStats()
    {
        return $this->hasMany(ClanMemberStat::class);
    }

    public function missions()
    {
        return $this->hasMany(ClanMission::class);
    }

    public function bonuses()
    {
        return $this->hasMany(ClanBonus::class);
    }

    public function gameTransfers()
    {
        return $this->hasMany(ClanGameTransfer::class);
    }

    public function attacksLaunched()
    {
        return $this->hasMany(ClanAttack::class, 'attacker_clan_id');
    }

    public function attacksReceived()
    {
        return $this->hasMany(ClanAttack::class, 'defender_clan_id');
    }

    // the private forum of the clan (App\Services\ClanForumService)
    public function forumTopics()
    {
        return $this->hasMany(ClanForumTopic::class);
    }

    // the wars declared by the clan (3 at most)
    public function wars()
    {
        return $this->hasMany(ClanWar::class);
    }
}
