<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PoidsPlumeResult extends Model
{
    protected $fillable = [
        'period_id',
        'user_id',
        'game_ids',
        'feathers_count',
        'jackpot_total',
        'shared_pool_total',
        'reward',
        'user_point_id',
    ];

    protected $casts = [
        'game_ids' => 'array',
        'feathers_count' => 'integer',
        'jackpot_total' => 'integer',
        'shared_pool_total' => 'integer',
        'reward' => 'integer',
    ];

    public function period()
    {
        return $this->belongsTo(Period::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function userPoint()
    {
        return $this->belongsTo(UserPoint::class);
    }
}
