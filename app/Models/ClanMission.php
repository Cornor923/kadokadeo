<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ClanMission extends Model
{
    public const ACTIVE = 'active';

    public const COMPLETED = 'completed';

    // not finished in time
    public const FAILED = 'failed';

    // replaced by the "Mission suivante" bonus (a new mission of the same number, no point lost)
    public const SKIPPED = 'skipped';

    protected $fillable = ['clan_id', 'period_id', 'number', 'status', 'points', 'expires_at', 'completed_at'];

    protected $casts = [
        'points' => 'integer',
        'expires_at' => 'datetime',
        'completed_at' => 'datetime',
    ];

    public function clan()
    {
        return $this->belongsTo(Clan::class);
    }

    public function period()
    {
        return $this->belongsTo(Period::class);
    }

    public function steps()
    {
        return $this->hasMany(ClanMissionStep::class)->orderBy('id');
    }

    // the option won with the mission (by chance, App\Settings\ClanSettings::$bonus_chance)
    public function bonus()
    {
        return $this->hasOne(ClanBonus::class);
    }
}
