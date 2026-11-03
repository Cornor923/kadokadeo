<?php

namespace App\Models;

use App\Enums\ClanAttackStatus;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ClanAttack extends Model
{
    protected $fillable = [
        'period_id',
        'game_id',
        'attacker_clan_id',
        'attacker_user_id',
        'defender_clan_id',
        'run_id',
        'score',
        'status',
        'expires_at',
        'defender_user_id',
        'defense_run_id',
        'points',
        'resolved_at',
        'reserved_by_user_id',
        'reserved_at',
    ];

    protected $casts = [
        'status' => ClanAttackStatus::class,
        'score' => 'integer',
        'points' => 'integer',
        'expires_at' => 'datetime',
        'resolved_at' => 'datetime',
        'reserved_at' => 'datetime',
    ];

    public function period()
    {
        return $this->belongsTo(Period::class);
    }

    /** @return BelongsTo<Game, $this> */
    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class);
    }

    public function attackerClan()
    {
        return $this->belongsTo(Clan::class, 'attacker_clan_id');
    }

    public function attackerUser()
    {
        return $this->belongsTo(User::class, 'attacker_user_id');
    }

    public function defenderClan()
    {
        return $this->belongsTo(Clan::class, 'defender_clan_id');
    }

    public function defenderUser()
    {
        return $this->belongsTo(User::class, 'defender_user_id');
    }

    // the member of the attacked clan who said he will defend
    public function reservedBy()
    {
        return $this->belongsTo(User::class, 'reserved_by_user_id');
    }

    public function run()
    {
        return $this->belongsTo(Run::class);
    }

    public function defenseRun()
    {
        return $this->belongsTo(Run::class, 'defense_run_id');
    }

    public function scopeActive($query)
    {
        return $query->where('status', ClanAttackStatus::ACTIVE);
    }
}
