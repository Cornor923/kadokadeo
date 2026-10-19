<?php

namespace App\Contracts;

use App\Models\User;

// A content the players can report (App\Services\ReportService), shown in the queue « Modération > Signalements » of the
// admin (App\Filament\Resources\Reports\ReportResource).
//
// The reports (table `reports`, App\Models\Report) point to the content through a morph relation: its model needs an
// alias in the morph map (AppServiceProvider::boot) and a `reports()` relation (morphMany Report, 'reportable'). A player
// reports a content once; a report is open until an admin ignores it (dismissed) or acts on the content (actioned: all the
// open reports of the content are closed together). Adding a new kind of content: .opencode/skills/reporting/SKILL.md.
interface Reportable
{
    // the kind of content, in French ("Commentaire de replay")
    public function reportLabel(): string;

    // the content as the admin reads it in the queue (plain text)
    public function reportExcerpt(): ?string;

    // the author of the content (the action "Bannir" of the queue), null when he is gone
    public function reportAuthor(): ?User;

    // the page of the admin where the content is (with its context)
    public function reportAdminUrl(): ?string;

    // the action "Supprimer le contenu" of the queue, by the admin $moderator (the reports are closed by ReportService)
    public function moderateFromReport(User $moderator): void;
}
