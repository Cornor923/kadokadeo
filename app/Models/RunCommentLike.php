<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

// a player likes a comment of a replay (run_comments.likes_count counts them)
class RunCommentLike extends Model
{
    public const UPDATED_AT = null;

    public $incrementing = false;

    protected $primaryKey = null;

    protected $fillable = ['comment_id', 'user_id'];

    public function comment()
    {
        return $this->belongsTo(RunComment::class, 'comment_id');
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
