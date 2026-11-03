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

    /**
     * @return BelongsTo<Period, $this>
     */
    public function period(): BelongsTo
    {
        return $this->belongsTo(Period::class);
    }

    /**
     * @return BelongsTo<Game, $this>
     */
    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class);
    }

    /**
     * @return BelongsTo<Clan, $this>
     */
    public function attackerClan(): BelongsTo
    {
        return $this->belongsTo(Clan::class, 'attacker_clan_id');
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function attackerUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'attacker_user_id');
    }

    /**
     * @return BelongsTo<Clan, $this>
     */
    public function defenderClan(): BelongsTo
    {
        return $this->belongsTo(Clan::class, 'defender_clan_id');
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function defenderUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'defender_user_id');
    }

    // the member of the attacked clan who said he will defend
    /**
     * @return BelongsTo<User, $this>
     */
    public function reservedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reserved_by_user_id');
    }

    /**
     * @return BelongsTo<Run, $this>
     */
    public function run(): BelongsTo
    {
        return $this->belongsTo(Run::class);
    }

    /**
     * @return BelongsTo<Run, $this>
     */
    public function defenseRun(): BelongsTo
    {
        return $this->belongsTo(Run::class, 'defense_run_id');
    }

    public function scopeActive($query)
    {
        return $query->where('status', ClanAttackStatus::ACTIVE);
    }
}
