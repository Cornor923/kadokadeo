<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Period extends Model
{
    use HasFactory;

    public const DAYS_PER_PERIOD = 13;

    public $timestamps = false;

    protected $fillable = ['start_at', 'end_at'];

    protected $casts = [
        'start_at' => 'datetime',
        'end_at' => 'datetime',
    ];

    public function scopeCurrent($query)
    {
        return $query->where('start_at', '<', now())->where('end_at', '>', now())->orderBy('end_at');
    }

    public function runs()
    {
        return $this->hasMany(Run::class);
    }

    public function leagueMemberships()
    {
        return $this->hasMany(LeagueMembership::class);
    }

    public function leaguePromotions()
    {
        return $this->hasMany(LeaguePromotion::class);
    }

    public function poidsPlumeResults()
    {
        return $this->hasMany(PoidsPlumeResult::class);
    }

    public function dailyRankingResults()
    {
        return $this->hasMany(DailyRankingResult::class);
    }
}
