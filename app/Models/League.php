<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class League extends Model
{
    use HasFactory;

    protected $fillable = [
        'level',
        'name',
        'promotion_max_slots',
        'promotion_ratio_divisor',
        'promotion_min_stars',
        'promotion_reward',
    ];

    protected $casts = [
        'level' => 'integer',
        'promotion_max_slots' => 'integer',
        'promotion_ratio_divisor' => 'integer',
        'promotion_min_stars' => 'integer',
        'promotion_reward' => 'integer',
    ];

    /**
     * Number of players promoted to the next league at the end of the period.
     */
    public function getPromotionSlots(int $activePlayersCount): int
    {
        if ($activePlayersCount === 0) {
            return 0;
        }

        $ratioSlots = $this->promotion_ratio_divisor
            ? intdiv($activePlayersCount + $this->promotion_ratio_divisor - 1, $this->promotion_ratio_divisor)
            : null;

        $maxSlots = $this->promotion_max_slots;

        $slots = match (true) {
            $ratioSlots !== null && $maxSlots !== null => min($ratioSlots, $maxSlots),
            $ratioSlots !== null => $ratioSlots,
            $maxSlots !== null => $maxSlots,
            default => 0,
        };

        return min($slots, $activePlayersCount);
    }

    public function scopeOrdered($query)
    {
        return $query->orderBy('level');
    }

    public function runs()
    {
        return $this->hasMany(Run::class);
    }

    public function memberships()
    {
        return $this->hasMany(LeagueMembership::class);
    }

    public function promotionsFrom()
    {
        return $this->hasMany(LeaguePromotion::class, 'from_league_id');
    }

    public function promotionsTo()
    {
        return $this->hasMany(LeaguePromotion::class, 'to_league_id');
    }
}
