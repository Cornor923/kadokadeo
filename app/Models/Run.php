<?php

namespace App\Models;

use App\Casts\BinaryCast;
use App\Enums\RunVerification;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Run extends Model
{
    use HasFactory;
    use HasUlids;
    use SoftDeletes;

    protected $fillable = ['period_id', 'game_id', 'user_id', 'league_id', 'score', 'play_time_seconds', 'replay', 'completed_at', 'contract_score', 'contract_points', 'seed', 'score_details', 'daily_game_id', 'is_cheat', 'game_build_id', 'verification', 'verified_at', 'anticheat_flags', 'replay_frames'];

    protected $casts = [
        'replay' => BinaryCast::class,
        'completed_at' => 'datetime',
        'score_details' => 'array',
        'is_cheat' => 'boolean',
        'verification' => RunVerification::class,
        'verified_at' => 'datetime',
        'anticheat_flags' => 'integer',
        'replay_frames' => 'integer',
        'views_count' => 'integer',
        'comments_count' => 'integer',
    ];

    public function game()
    {
        return $this->belongsTo(Game::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function period()
    {
        return $this->belongsTo(Period::class);
    }

    public function league()
    {
        return $this->belongsTo(League::class);
    }

    // the version of the game the run was played with (its replay is played by the same version)
    public function gameBuild()
    {
        return $this->belongsTo(GameBuild::class);
    }

    // in the queue of the suspicious runs (App\Services\SuspicionService)
    public function flags()
    {
        return $this->hasMany(RunFlag::class);
    }

    // the comments of its replay and their answers (App\Services\RunCommentService)
    public function comments()
    {
        return $this->hasMany(RunComment::class);
    }

    public function getHasReplayAttribute()
    {
        return !is_null($this->replay);
    }

    // a run of today's daily game: every player has the same seed, so its seed and replay (the coming pieces) are
    // only shown to its player and the admins until the day is over
    public function isHiddenDailyFor(?User $user): bool
    {
        if ($this->daily_game_id === null || $this->daily_game_id !== self::todayDailyGameId()) {
            return false;
        }

        return !$user || ($user->id !== $this->user_id && !$user->is_admin);
    }

    private static function todayDailyGameId(): ?int
    {
        return once(fn () => DailyGame::where('day', today())->value('id'));
    }
}
