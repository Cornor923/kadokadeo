<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DailyRankingResult extends Model
{
    protected $fillable = [
        'period_id',
        'user_id',
        'rank_position',
        'points',
        'reward',
        'user_point_id',
    ];

    protected $casts = [
        'rank_position' => 'integer',
        'points' => 'integer',
        'reward' => 'integer',
    ];

    public function period()
    {
        return $this->belongsTo(Period::class);
    }

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function userPoint()
    {
        return $this->belongsTo(UserPoint::class);
    }
}
