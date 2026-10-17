<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ClanApplication extends Model
{
    public const PENDING = 'pending';

    public const ACCEPTED = 'accepted';

    public const REFUSED = 'refused';

    protected $fillable = ['clan_id', 'user_id', 'message', 'status'];

    public function clan()
    {
        return $this->belongsTo(Clan::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
