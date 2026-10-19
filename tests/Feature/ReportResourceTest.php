<?php

namespace Tests\Feature;

use App\Enums\ReportReason;
use App\Enums\ReportStatus;
use App\Filament\Resources\Reports\Pages\ListReports;
use App\Filament\Resources\Runs\Pages\ViewRun;
use App\Filament\Resources\Runs\RelationManagers\CommentsRelationManager;
use App\Models\Report;
use App\Models\Run;
use App\Models\RunComment;
use App\Models\User;
use App\Services\ReportService;
use App\Services\RunCommentService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class ReportResourceTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $this->admin = User::factory()->create(['is_admin' => true]);
        $this->actingAs($this->admin);
    }

    private function comment(?Run $run = null): RunComment
    {
        $run ??= Run::factory()->create(['replay' => 'replay-data']);

        return app(RunCommentService::class)->create(User::factory()->create(), $run, 32, 'Commentaire signalé');
    }

    private function report(RunComment $comment): Report
    {
        return app(ReportService::class)->report(User::factory()->create(), $comment, ReportReason::SPAM, 'Pub');
    }

    public function test_the_admin_sees_the_open_reports(): void
    {
        $open = $this->report($this->comment());
        $dismissed = $this->report($this->comment());
        $dismissed->update(['status' => ReportStatus::DISMISSED]);

        $this->get('/admin/reports')->assertOk()->assertSee('Signalements');
        Livewire::test(ListReports::class)
            ->assertCanSeeTableRecords([$open])
            ->assertCanNotSeeTableRecords([$dismissed])
            ->assertSee('Commentaire signalé');
    }

    // ignoring or deleting closes every open report of the content
    public function test_the_admin_ignores_the_reports_or_deletes_the_content(): void
    {
        $comment = $this->comment();
        $first = $this->report($comment);
        $second = $this->report($comment);
        Livewire::test(ListReports::class)->callTableAction('dismiss', $first);
        $this->assertSame(ReportStatus::DISMISSED, $second->refresh()->status);
        $this->assertFalse($comment->refresh()->trashed());

        $other = $this->comment();
        $report = $this->report($other);
        Livewire::test(ListReports::class)->callTableAction('moderate', $report);
        $this->assertSame(ReportStatus::ACTIONED, $report->refresh()->status);
        $this->assertSame($this->admin->id, $report->reviewed_by);
        $this->assertTrue($other->refresh()->trashed());
        $this->assertSame(0, $other->run->refresh()->comments_count);
    }

    public function test_the_page_of_a_run_shows_its_comments(): void
    {
        $run = Run::factory()->create(['replay' => 'replay-data', 'replay_frames' => 640]);
        $comment = $this->comment($run);

        $this->get("/admin/runs/{$run->id}")->assertOk()->assertSee('Détails')->assertSee('Commentaires');
        // a run without replay too (RunPolicy::view refuses it on the site)
        $this->get('/admin/runs/'.Run::factory()->create()->id)->assertOk();

        Livewire::test(CommentsRelationManager::class, ['ownerRecord' => $run, 'pageClass' => ViewRun::class])
            ->assertCanSeeTableRecords([$comment])
            ->callTableAction('edit', $comment, ['content' => 'Modéré'])
            ->callTableAction('deleteComment', $comment);
        $this->assertSame('Modéré', $comment->refresh()->content);
        $this->assertTrue($comment->trashed());

        Livewire::test(CommentsRelationManager::class, ['ownerRecord' => $run, 'pageClass' => ViewRun::class])
            ->filterTable('trashed', true)
            ->callTableAction('restoreComment', $comment);
        $this->assertFalse($comment->refresh()->trashed());
        $this->assertSame(1, $run->refresh()->comments_count);
    }
}
