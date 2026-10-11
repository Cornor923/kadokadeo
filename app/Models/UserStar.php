<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class UserStar extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'user_id',
        'period_id',
        'green_stars',
        'orange_stars',
        'red_stars',
        'purple_stars',
    ];

    protected $casts = [
        'green_stars' => 'integer',
        'orange_stars' => 'integer',
        'red_stars' => 'integer',
        'purple_stars' => 'integer',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function period()
    {
        return $this->belongsTo(Period::class);
    }
}
