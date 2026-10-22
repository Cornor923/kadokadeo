<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LeaguePromotion extends Model
{
    protected $fillable = [
        'period_id',
        'next_period_id',
        'game_id',
        'user_id',
        'from_league_id',
        'to_league_id',
        'run_id',
        'rank_position',
        'score',
        'play_time_seconds',
        'promotion_slots',
        'active_players_count',
        'promotion_reward',
        'user_point_id',
    ];

    protected $casts = [
        'rank_position' => 'integer',
        'score' => 'integer',
        'play_time_seconds' => 'integer',
        'promotion_slots' => 'integer',
        'active_players_count' => 'integer',
        'promotion_reward' => 'integer',
    ];

    public function period()
    {
        return $this->belongsTo(Period::class);
    }

    public function nextPeriod()
    {
        return $this->belongsTo(Period::class, 'next_period_id');
    }

    /**
     * @return BelongsTo<Game, $this>
     */
    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function fromLeague()
    {
        return $this->belongsTo(League::class, 'from_league_id');
    }

    public function toLeague()
    {
        return $this->belongsTo(League::class, 'to_league_id');
    }

    public function run()
    {
        return $this->belongsTo(Run::class);
    }

    public function userPoint()
    {
        return $this->belongsTo(UserPoint::class);
    }
}
