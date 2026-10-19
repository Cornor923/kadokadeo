<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ClanApplication extends Model
{
    public const PENDING = 'pending';

    public const ACCEPTED = 'accepted';

    public const REFUSED = 'refused';

    // closed without a decision of the clan: the player joined or created another clan, or the clan was disbanded
    public const CANCELLED = 'cancelled';

    // cost: the Kado points paid for it, refunded_at: when they were given back (App\Services\ClanService::closeApplication)
    protected $fillable = ['clan_id', 'user_id', 'message', 'status', 'cost', 'refunded_at'];

    protected $casts = [
        'cost' => 'integer',
        'refunded_at' => 'datetime',
    ];

    public function clan()
    {
        return $this->belongsTo(Clan::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
