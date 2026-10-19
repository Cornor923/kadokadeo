<?php

namespace App\Services;

use App\Contracts\Reportable;
use App\Enums\ReportReason;
use App\Enums\ReportStatus;
use App\Exceptions\RunCommentException;
use App\Models\Report;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

// The reports of the players (table `reports`), the queue « Modération > Signalements » of the admin
// (App\Filament\Resources\Reports\ReportResource). Any model implementing App\Contracts\Reportable can be reported
// (today the comments of the replays): see .opencode/skills/reporting/SKILL.md to add one.
//
// - A player reports a content once (unique reportable + reporter): reporting it again changes nothing. His own content,
//   or a deleted one, cannot be reported.
// - A report is "open" until an admin ignores it ("dismissed": the content stays) or acts on the content ("actioned":
//   Reportable::moderateFromReport, e.g. the comment deleted). Both close all the open reports of the content at once.
// - Deleting a content in any other way (its author, the admin page of the run) closes its open reports as "actioned".
// - Nothing is sanctioned automatically: banning the author is an action of the queue (ModerationActions::ban).
class ReportService
{
    public function report(User $reporter, Model&Reportable $content, ReportReason $reason, ?string $details = null): Report
    {
        if (in_array(SoftDeletes::class, class_uses_recursive($content)) && $content->trashed()) {
            throw new RunCommentException('Ce contenu a déjà été supprimé.');
        }
        $author = $content->reportAuthor();
        if ($author?->id === $reporter->id) {
            throw new RunCommentException('Vous ne pouvez pas signaler votre propre message.');
        }

        return Report::query()->firstOrCreate([
            'reportable_type' => $content->getMorphClass(),
            'reportable_id' => (string) $content->getKey(),
            'reporter_id' => $reporter->id,
        ], [
            'reported_user_id' => $author?->id,
            'reason' => $reason,
            'details' => filled($details) ? trim($details) : null,
        ]);
    }

    // the content stays: all its open reports are ignored
    public function dismissAll(Model&Reportable $content, User $admin): int
    {
        return $this->close($content, ReportStatus::DISMISSED, $admin);
    }

    // the content was dealt with (deleted): all its open reports are closed
    public function actionAll(Model&Reportable $content, ?User $admin): int
    {
        return $this->close($content, ReportStatus::ACTIONED, $admin);
    }

    // the action "Supprimer le contenu" of the queue
    public function moderate(Report $report, User $admin): void
    {
        $content = $report->reportable;
        if ($content instanceof Reportable) {
            $content->moderateFromReport($admin);
            $this->actionAll($content, $admin);

            return;
        }
        // the content is gone for good (force deleted)
        $this->review($report, ReportStatus::ACTIONED, $admin);
    }

    public function review(Report $report, ReportStatus $status, User $admin): void
    {
        $report->update(['status' => $status, 'reviewed_by' => $admin->id, 'reviewed_at' => now()]);
    }

    public static function openCount(): int
    {
        return Report::query()->where('status', ReportStatus::OPEN)->count();
    }

    private function close(Model&Reportable $content, ReportStatus $status, ?User $admin): int
    {
        return Report::query()
            ->where('reportable_type', $content->getMorphClass())
            ->where('reportable_id', (string) $content->getKey())
            ->where('status', ReportStatus::OPEN)
            ->update(['status' => $status, 'reviewed_by' => $admin?->id, 'reviewed_at' => now()]);
    }
}
