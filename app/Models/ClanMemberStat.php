<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ClanMemberStat extends Model
{
    protected $fillable = [
        'clan_id',
        'user_id',
        'period_id',
        'attacks',
        'attacks_won',
        'defenses',
        'defenses_won',
        'mission_steps',
        'performance',
        'reward',
        'user_point_id',
    ];

    /**
     * @return BelongsTo<Clan, $this>
     */
    public function clan(): BelongsTo
    {
        return $this->belongsTo(Clan::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function period()
    {
        return $this->belongsTo(Period::class);
    }

    public function userPoint()
    {
        return $this->belongsTo(UserPoint::class);
    }
}
