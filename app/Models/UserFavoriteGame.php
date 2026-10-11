<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class UserFavoriteGame extends Model
{
    protected $guarded = [];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function game()
    {
        return $this->belongsTo(Game::class);
    }
}
