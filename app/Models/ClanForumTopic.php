<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

// a topic of the private forum of a clan (App\Services\ClanForumService)
class ClanForumTopic extends Model
{
    use HasFactory;

    // the messages shown on a page of a topic: the old forum showed 10
    public const MESSAGES_PER_PAGE = 10;

    protected $fillable = [
        'clan_id', 'user_id', 'title', 'is_pinned', 'is_locked', 'replies_count', 'last_message_id',
        'last_message_user_id', 'last_message_at',
    ];

    protected $casts = [
        'is_pinned' => 'boolean',
        'is_locked' => 'boolean',
        'replies_count' => 'integer',
        'last_message_at' => 'datetime',
    ];

    /** @return BelongsTo<Clan, $this> */
    public function clan(): BelongsTo
    {
        return $this->belongsTo(Clan::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function lastMessageUser()
    {
        return $this->belongsTo(User::class, 'last_message_user_id');
    }

    // the deleted messages too: they are shown as deleted
    public function messages()
    {
        return $this->hasMany(ClanForumMessage::class, 'topic_id')->withTrashed();
    }

    public function reads()
    {
        return $this->hasMany(ClanForumRead::class, 'topic_id');
    }

    // the pages of the topic (the first message and its answers)
    public function pages(): int
    {
        return (int) ceil(($this->replies_count + 1) / self::MESSAGES_PER_PAGE);
    }
}
