<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

// a war declared by a clan to another one (App\Services\ClanWarService::declareWar)
class ClanWar extends Model
{
    protected $fillable = [
        'clan_id',
        'target_clan_id',
        'declared_by_user_id',
    ];

    public function clan()
    {
        return $this->belongsTo(Clan::class);
    }

    public function targetClan()
    {
        return $this->belongsTo(Clan::class, 'target_clan_id');
    }

    public function declaredBy()
    {
        return $this->belongsTo(User::class, 'declared_by_user_id');
    }
}
