<?php

namespace App\Models;

use App\Enums\ClanActionType;
use Illuminate\Database\Eloquent\Model;

class ClanAction extends Model
{
    protected $fillable = [
        'clan_id',
        'user_id',
        'game_id',
        'type',
        'defender_clan_id',
        'clan_attack_id',
        'clan_mission_step_id',
        'run_id',
        'result',
        'completed_at',
    ];

    protected $casts = [
        'type' => ClanActionType::class,
        'completed_at' => 'datetime',
    ];

    public function clan()
    {
        return $this->belongsTo(Clan::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function game()
    {
        return $this->belongsTo(Game::class);
    }

    public function defenderClan()
    {
        return $this->belongsTo(Clan::class, 'defender_clan_id');
    }

    public function attack()
    {
        return $this->belongsTo(ClanAttack::class, 'clan_attack_id');
    }

    public function missionStep()
    {
        return $this->belongsTo(ClanMissionStep::class, 'clan_mission_step_id');
    }

    public function run()
    {
        return $this->belongsTo(Run::class);
    }
}
