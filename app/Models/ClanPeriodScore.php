<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ClanPeriodScore extends Model
{
    protected $fillable = [
        'clan_id',
        'period_id',
        'war_score',
        'mission_score',
        'attacks_won',
        'attacks_lost',
        'defenses_won',
        'missions_completed',
        'war_rank',
        'mission_rank',
        'reward',
        'closed_at',
    ];

    protected $casts = [
        'war_score' => 'integer',
        'mission_score' => 'integer',
        'closed_at' => 'datetime',
    ];

    public function clan()
    {
        return $this->belongsTo(Clan::class);
    }

    public function period()
    {
        return $this->belongsTo(Period::class);
    }
}
