<?php

namespace App\Models;

use App\Enums\ClanBonusType;
use Illuminate\Database\Eloquent\Model;

class ClanBonus extends Model
{
    protected $fillable = ['clan_id', 'period_id', 'clan_mission_id', 'type', 'used_at', 'game_id', 'doubled_mission_id'];

    protected $casts = [
        'type' => ClanBonusType::class,
        'used_at' => 'datetime',
    ];

    public function clan()
    {
        return $this->belongsTo(Clan::class);
    }

    public function period()
    {
        return $this->belongsTo(Period::class);
    }

    // the mission that won the option (none for the options given at the start of the period)
    public function mission()
    {
        return $this->belongsTo(ClanMission::class, 'clan_mission_id');
    }

    // the game added to the "Jeux caca" or the "Jeux cool" by the option
    public function game()
    {
        return $this->belongsTo(Game::class);
    }

    // "Double points" used and waiting for the next mission of the clan (ClanMissionService::generateMission)
    public function scopePendingDoublePoints($query, int $clanId, int $periodId)
    {
        return $query->where('clan_id', $clanId)
            ->where('period_id', $periodId)
            ->where('type', ClanBonusType::DOUBLE_POINTS)
            ->whereNotNull('used_at')
            ->whereNull('doubled_mission_id');
    }

    public function scopeAvailable($query)
    {
        return $query->whereNull('used_at');
    }
}
