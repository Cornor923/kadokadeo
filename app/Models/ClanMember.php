<?php

namespace App\Models;

use App\Enums\ClanCombatRole;
use App\Enums\ClanRole;
use Illuminate\Database\Eloquent\Model;

class ClanMember extends Model
{
    protected $fillable = ['clan_id', 'user_id', 'role', 'combat_role', 'combat_role_period_id', 'joined_period_id', 'status'];

    // the leader is clans.leader_id: his role stays "member" here (App\Services\ClanService::roleOf)
    protected $casts = [
        'role' => ClanRole::class,
        'combat_role' => ClanCombatRole::class,
    ];

    protected $attributes = [
        'role' => 'member',
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
