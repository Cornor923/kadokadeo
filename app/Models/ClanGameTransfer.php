<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

// paid clan games given to the clan by a member (DONATION) or given by the leader or a right hand to a member
// (DISTRIBUTION)
class ClanGameTransfer extends Model
{
    public const DONATION = 'donation';

    public const DISTRIBUTION = 'distribution';

    protected $fillable = ['clan_id', 'type', 'from_user_id', 'to_user_id', 'count'];

    protected $casts = [
        'count' => 'integer',
    ];

    public function clan()
    {
        return $this->belongsTo(Clan::class);
    }

    public function fromUser()
    {
        return $this->belongsTo(User::class, 'from_user_id');
    }

    public function toUser()
    {
        return $this->belongsTo(User::class, 'to_user_id');
    }
}
