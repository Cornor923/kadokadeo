<?php

namespace App\Models;

use App\Contracts\Reportable;
use App\Filament\Resources\Runs\RunResource;
use App\Services\RunCommentService;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

// a comment of a replay at one of its frames (App\Services\RunCommentService), or an answer to one (parent_id)
class RunComment extends Model implements Reportable
{
    use HasFactory;
    use SoftDeletes;

    // the frames of a replay by second (FixedFramerate.STEP of the games, resources/js/composables/useReplayClock.js)
    public const FPS = 32;

    protected $fillable = ['run_id', 'user_id', 'parent_id', 'frame', 'content', 'edited_at', 'deleted_by'];

    protected $casts = [
        'frame' => 'integer',
        'likes_count' => 'integer',
        'replies_count' => 'integer',
        'edited_at' => 'datetime',
    ];

    /** @return BelongsTo<Run, $this> */
    public function run(): BelongsTo
    {
        return $this->belongsTo(Run::class)->withTrashed();
    }

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** @return BelongsTo<self, $this> */
    public function parent(): BelongsTo
    {
        return $this->belongsTo(self::class, 'parent_id')->withTrashed();
    }

    public function replies()
    {
        return $this->hasMany(self::class, 'parent_id');
    }

    public function likes()
    {
        return $this->hasMany(RunCommentLike::class, 'comment_id');
    }

    public function reports()
    {
        return $this->morphMany(Report::class, 'reportable');
    }

    // the moment of the replay, "mm:ss"
    public function timecode(): string
    {
        $seconds = intdiv($this->frame, self::FPS);

        return sprintf('%02d:%02d', intdiv($seconds, 60), $seconds % 60);
    }

    public function reportLabel(): string
    {
        return $this->parent_id ? 'Réponse à un commentaire de replay' : 'Commentaire de replay';
    }

    public function reportExcerpt(): ?string
    {
        return $this->content;
    }

    public function reportAuthor(): ?User
    {
        return $this->user;
    }

    public function reportAdminUrl(): ?string
    {
        return RunResource::getUrl('view', ['record' => $this->run_id, 'relation' => 'comments']);
    }

    public function moderateFromReport(User $moderator): void
    {
        app(RunCommentService::class)->delete($moderator, $this);
    }
}
