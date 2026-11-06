<?php

namespace App\Models;

use App\Enums\AchievementCategory;
use App\Enums\AchievementProgressScope;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Achievement extends Model
{
    use HasFactory;

    protected $fillable = ['game_id', 'key', 'category', 'progress_scope', 'is_active'];

    protected $casts = [
        'category' => AchievementCategory::class,
        'progress_scope' => AchievementProgressScope::class,
        'is_active' => 'boolean',
    ];

    /**
     * @return BelongsTo<Game, $this>
     */
    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class);
    }

    /**
     * @return HasMany<AchievementLevel, $this>
     */
    public function levels(): HasMany
    {
        return $this->hasMany(AchievementLevel::class)->orderBy('level');
    }

    public function progress()
    {
        return $this->hasMany(UserAchievementProgress::class);
    }
}
