<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ClanMissionStep extends Model
{
    protected $fillable = [
        'clan_mission_id',
        'game_id',
        'target_score',
        'completed_by_user_id',
        'run_id',
        'score',
        'skipped',
        'completed_at',
        'reserved_by_user_id',
        'reserved_at',
    ];

    protected $casts = [
        'target_score' => 'integer',
        'score' => 'integer',
        'skipped' => 'boolean',
        'completed_at' => 'datetime',
        'reserved_at' => 'datetime',
    ];

    public function mission()
    {
        return $this->belongsTo(ClanMission::class, 'clan_mission_id');
    }

    public function game()
    {
        return $this->belongsTo(Game::class);
    }

    // the member who said he will complete the step
    public function reservedBy()
    {
        return $this->belongsTo(User::class, 'reserved_by_user_id');
    }

    public function completedBy()
    {
        return $this->belongsTo(User::class, 'completed_by_user_id');
    }

    public function isDone(): bool
    {
        return $this->completed_at !== null || $this->skipped;
    }
}
