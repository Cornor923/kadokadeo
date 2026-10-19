---
name: reporting
description: The reports of the players (« Signaler ») and the admin queue « Modération > Signalements »: how they work, how to make a new kind of content reportable.
---

# Reports (signalements)

The players report a content they find abusive; the admins read the reports in **Modération > Signalements**
(`app/Filament/Resources/Reports`). Today the comments of the replays (`App\Models\RunComment`) can be reported; the
system is generic, any model can join it.

## How it works

- Table `reports` (`App\Models\Report`): `reportable_type` / `reportable_id` (morph relation to the content, the type is
  an **alias** of the morph map, e.g. `run_comment`), `reporter_id`, `reported_user_id` (the author when it was reported:
  the content can be deleted since), `reason` (`App\Enums\ReportReason`), `details` (free text, 500 max), `status`
  (`App\Enums\ReportStatus`), `reviewed_by` / `reviewed_at`.
- `App\Services\ReportService` holds the rules:
  - **one report by player and content** (unique key + `firstOrCreate`): reporting again changes nothing;
  - his own content, or a deleted one, cannot be reported;
  - a report stays `open` until an admin **ignores** it (`dismissed`: the content stays) or **acts** on the content
    (`actioned`: `Reportable::moderateFromReport`, e.g. the comment deleted). Both close **all** the open reports of the
    content at once (`dismissAll` / `actionAll`);
  - deleting the content in any other way (its author, the admin page of the run) closes its open reports as `actioned`
    (the service of the content calls `ReportService::actionAll`);
  - nothing is sanctioned automatically: banning the author is an action of the queue (`ModerationActions::ban`).
- The queue shows one row by report, with the number of open reports on the same content; the navigation badge counts
  the open ones (`ReportService::openCount`).
- The players reach it through the API of the content (comments: `POST /api/run-comments/{comment}/report`,
  `throttle:10,1,reports`), the reasons sent to the page with the content (`ReportReason::options()`).

## Make a new kind of content reportable

1. The model implements `App\Contracts\Reportable` (`reportLabel`, `reportExcerpt`, `reportAuthor`, `reportAdminUrl`,
   `moderateFromReport`) and has a `reports()` relation: `morphMany(Report::class, 'reportable')`.
   `Report::reportable()` loads the contents `withTrashed()`: the model needs `SoftDeletes` (or change that relation).
2. Give it an alias in the morph map (`AppServiceProvider::boot`, `Relation::morphMap`, max 32 characters): the « Type »
   filter of the queue lists the aliases of the morph map.
3. Its deletion (service of the content) calls `ReportService::actionAll($content, $user)`.
4. A route `POST .../{content}/report` (validation `reason` = `Rule::enum(ReportReason::class)`, `details` max 500) with
   its throttle (`throttle:10,1,reports`), calling `ReportService::report`.
5. Tests: like `tests/Feature/RunCommentTest.php` (`test_a_comment_is_reported`) and
   `tests/Feature/ReportResourceTest.php`.
