<?php

namespace App\Models;

use App\Contracts\Reportable;
use App\Enums\ReportReason;
use App\Enums\ReportStatus;
use Illuminate\Database\Eloquent\Model;

// a player reports a content (App\Contracts\Reportable, App\Services\ReportService): the queue « Modération >
// Signalements » of the admin
class Report extends Model
{
    protected $fillable = ['reportable_type', 'reportable_id', 'reporter_id', 'reported_user_id', 'reason', 'details', 'status', 'reviewed_by', 'reviewed_at'];

    protected $casts = [
        'reason' => ReportReason::class,
        'status' => ReportStatus::class,
        'reviewed_at' => 'datetime',
    ];

    protected $attributes = [
        'status' => 'open',
    ];

    /**
     * The reported content, deleted ones too (an admin reads what was deleted).
     *
     * @return \Illuminate\Database\Eloquent\Relations\MorphTo<Model&Reportable, $this>
     */
    public function reportable()
    {
        return $this->morphTo()->withTrashed();
    }

    public function reporter()
    {
        return $this->belongsTo(User::class, 'reporter_id');
    }

    public function reportedUser()
    {
        return $this->belongsTo(User::class, 'reported_user_id');
    }

    public function reviewer()
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }
}
