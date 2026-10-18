<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

// the last message read by a player in a topic of the forum of his clan
class ClanForumRead extends Model
{
    protected $fillable = ['user_id', 'topic_id', 'last_read_message_id'];
}
