<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

// a message of the private forum of a clan, written in Marktwin (rendered by the client). Deleted by a moderator, it is
// kept (soft delete) to be restored.
class ClanForumMessage extends Model
{
    use HasFactory;
    use SoftDeletes;

    protected $fillable = ['topic_id', 'user_id', 'content', 'edited_at', 'edited_by', 'deleted_by'];

    protected $casts = [
        'edited_at' => 'datetime',
    ];

    /** @return BelongsTo<ClanForumTopic, $this> */
    public function topic(): BelongsTo
    {
        return $this->belongsTo(ClanForumTopic::class, 'topic_id');
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
