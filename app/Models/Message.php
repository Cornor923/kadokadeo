<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

// a private message (sender null: a message of the site, signed "KadoKado")
class Message extends Model
{
    protected $fillable = ['sender_id', 'recipient_id', 'subject', 'body', 'read_at', 'sender_deleted_at', 'recipient_deleted_at'];

    protected $casts = [
        'read_at' => 'datetime',
        'sender_deleted_at' => 'datetime',
        'recipient_deleted_at' => 'datetime',
    ];

    /** @return BelongsTo<User, $this> */
    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    /** @return BelongsTo<User, $this> */
    public function recipient(): BelongsTo
    {
        return $this->belongsTo(User::class, 'recipient_id');
    }

    public function scopeInboxOf($query, User $user)
    {
        return $query->where('recipient_id', $user->id)->whereNull('recipient_deleted_at');
    }

    public function scopeSentBy($query, User $user)
    {
        return $query->where('sender_id', $user->id)->whereNull('sender_deleted_at');
    }
}
