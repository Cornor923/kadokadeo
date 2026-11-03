<?php

namespace App\Models;

use App\Enums\NotificationType;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\MassPrunable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

// a notification of a player (App\Services\NotificationService), in the tab « Notifications » of his messages
class UserNotification extends Model
{
    use MassPrunable;

    // removed two months after their last change (model:prune, routes/console.php)
    public const KEEP_MONTHS = 2;

    protected $fillable = ['user_id', 'type', 'actor_id', 'run_id', 'comment_id', 'clan_id', 'clan_application_id', 'count', 'group_key', 'read_at'];

    protected $casts = [
        'type' => NotificationType::class,
        'count' => 'integer',
        'read_at' => 'datetime',
    ];

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** @return BelongsTo<User, $this> */
    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_id');
    }

    /** @return BelongsTo<Run, $this> */
    public function run(): BelongsTo
    {
        return $this->belongsTo(Run::class);
    }

    // not the deleted ones: their notifications are removed with them (App\Services\RunCommentService::delete)
    /** @return BelongsTo<RunComment, $this> */
    public function comment(): BelongsTo
    {
        return $this->belongsTo(RunComment::class, 'comment_id');
    }

    /** @return BelongsTo<Clan, $this> */
    public function clan(): BelongsTo
    {
        return $this->belongsTo(Clan::class);
    }

    public function scopeUnread(Builder $query): void
    {
        $query->whereNull('read_at');
    }

    public function prunable(): Builder
    {
        return static::where('updated_at', '<', now()->subMonths(self::KEEP_MONTHS));
    }
}
