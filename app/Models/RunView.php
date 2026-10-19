<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

// a player watched a replay (App\Services\RunViewService): runs.views_count counts them
class RunView extends Model
{
    public const UPDATED_AT = null;

    public $incrementing = false;

    protected $primaryKey = null;

    protected $fillable = ['run_id', 'user_id'];

    public function run()
    {
        return $this->belongsTo(Run::class)->withTrashed();
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
