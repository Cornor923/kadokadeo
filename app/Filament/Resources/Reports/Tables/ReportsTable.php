<?php

namespace App\Filament\Resources\Reports\Tables;

use App\Contracts\Reportable;
use App\Enums\ReportReason;
use App\Enums\ReportStatus;
use App\Filament\Resources\Users\Actions\ModerationActions;
use App\Models\Report;
use App\Services\ReportService;
use Filament\Actions\Action;
use Filament\Actions\ActionGroup;
use Filament\Actions\BulkAction;
use Filament\Actions\BulkActionGroup;
use Filament\Notifications\Notification;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Support\Facades\DB;

// one row by report: the reports of the same content are closed together (ReportService)
class ReportsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn (Builder $query) => $query
                ->with(['reportable', 'reporter', 'reportedUser'])
                // the reports of the same content
                ->addSelect(['same_content_count' => Report::query()
                    ->from('reports as same')
                    ->selectRaw('count(*)')
                    ->whereColumn('same.reportable_type', 'reports.reportable_type')
                    ->whereColumn('same.reportable_id', 'reports.reportable_id')
                    ->where('same.status', ReportStatus::OPEN)]))
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('created_at')
                    ->label('Date')
                    ->dateTime('d/m/Y H:i')
                    ->sortable(),
                TextColumn::make('reportable_type')
                    ->label('Type')
                    ->formatStateUsing(fn (Report $record) => self::content($record)?->reportLabel() ?? self::typeLabel($record->reportable_type))
                    ->toggleable(),
                TextColumn::make('excerpt')
                    ->label('Contenu')
                    ->state(fn (Report $record) => self::content($record)?->reportExcerpt() ?? 'Contenu effacé')
                    ->description(fn (Report $record) => self::isDeleted($record) ? 'Supprimé' : null)
                    ->limit(80)
                    ->tooltip(fn (Report $record) => self::content($record)?->reportExcerpt())
                    ->wrap(),
                TextColumn::make('reportedUser.display_name')
                    ->label('Auteur')
                    ->placeholder('—')
                    ->searchable(),
                TextColumn::make('reporter.display_name')
                    ->label('Signalé par')
                    ->searchable(),
                TextColumn::make('reason')
                    ->label('Motif')
                    ->badge(),
                TextColumn::make('details')
                    ->label('Précisions')
                    ->placeholder('—')
                    ->limit(60)
                    ->tooltip(fn (Report $record) => $record->details)
                    ->wrap()
                    ->toggleable(),
                TextColumn::make('same_content_count')
                    ->label('Signalements ouverts du contenu')
                    ->badge()
                    ->color(fn (int $state) => $state > 1 ? 'danger' : 'gray'),
                TextColumn::make('status')
                    ->label('Statut')
                    ->badge(),
            ])
            ->filters([
                SelectFilter::make('status')
                    ->label('Statut')
                    ->options(ReportStatus::class)
                    ->default(ReportStatus::OPEN->value),
                SelectFilter::make('reportable_type')
                    ->label('Type')
                    ->options(fn () => collect(Relation::morphMap())
                        ->keys()
                        ->mapWithKeys(fn (string $alias) => [$alias => self::typeLabel($alias)])
                        ->all()),
                SelectFilter::make('reason')
                    ->label('Motif')
                    ->options(ReportReason::class),
            ])
            ->recordActions([
                self::readAction(),
                ActionGroup::make([
                    Action::make('openContent')
                        ->label('Voir dans son contexte')
                        ->icon(Heroicon::OutlinedArrowTopRightOnSquare)
                        ->visible(fn (Report $record) => self::content($record)?->reportAdminUrl() !== null)
                        ->url(fn (Report $record) => self::content($record)?->reportAdminUrl()),
                    self::dismissAction(),
                    self::moderateAction(),
                    ModerationActions::ban(fn (Report $record) => $record->reportedUser),
                ]),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    BulkAction::make('dismiss')
                        ->label('Ignorer')
                        ->icon(Heroicon::OutlinedCheck)
                        ->requiresConfirmation()
                        ->action(function (Collection $records, ReportService $reports): void {
                            $records->each(fn (Report $report) => self::dismiss($report, $reports));

                            Notification::make()->title('Signalements ignorés.')->success()->send();
                        }),
                ]),
            ]);
    }

    private static function content(Report $report): ?Reportable
    {
        return $report->reportable instanceof Reportable ? $report->reportable : null;
    }

    private static function isDeleted(Report $report): bool
    {
        $content = $report->reportable;

        return $content === null || (method_exists($content, 'trashed') && $content->trashed());
    }

    // the label of a kind of content without one at hand (the content is gone)
    private static function typeLabel(string $alias): string
    {
        $class = Relation::getMorphedModel($alias);

        return $class && is_subclass_of($class, Reportable::class) ? (new $class())->reportLabel() : $alias;
    }

    private static function dismiss(Report $report, ReportService $reports): void
    {
        if ($report->status !== ReportStatus::OPEN) {
            return;
        }
        $content = self::content($report);
        $content ? $reports->dismissAll($content, auth()->user()) : $reports->review($report, ReportStatus::DISMISSED, auth()->user());
    }

    private static function readAction(): Action
    {
        return Action::make('read')
            ->label('Lire')
            ->icon(Heroicon::OutlinedEye)
            ->color('gray')
            ->modalHeading(fn (Report $record) => self::content($record)?->reportLabel() ?? 'Contenu effacé')
            ->modalContent(fn (Report $record) => view('filament.report', [
                'report' => $record,
                'content' => self::content($record),
                'deleted' => self::isDeleted($record),
                'others' => Report::query()
                    ->with('reporter')
                    ->where('reportable_type', $record->reportable_type)
                    ->where('reportable_id', $record->reportable_id)
                    ->whereKeyNot($record->id)
                    ->latest()
                    ->get(),
            ]))
            ->modalSubmitAction(false)
            ->modalCancelActionLabel('Fermer');
    }

    private static function dismissAction(): Action
    {
        return Action::make('dismiss')
            ->label('Ignorer')
            ->icon(Heroicon::OutlinedCheck)
            ->color('gray')
            ->visible(fn (Report $record) => $record->status === ReportStatus::OPEN)
            ->action(function (Report $record, ReportService $reports): void {
                self::dismiss($record, $reports);

                Notification::make()->title('Signalements du contenu ignorés.')->success()->send();
            });
    }

    private static function moderateAction(): Action
    {
        return Action::make('moderate')
            ->label('Supprimer le contenu')
            ->icon(Heroicon::OutlinedTrash)
            ->color('danger')
            ->visible(fn (Report $record) => $record->status === ReportStatus::OPEN && !self::isDeleted($record))
            ->requiresConfirmation()
            ->modalHeading('Supprimer le contenu')
            ->modalDescription('Le contenu est supprimé (restaurable depuis sa page) et tous ses signalements ouverts sont clos.')
            ->modalSubmitActionLabel('Supprimer')
            ->action(function (Report $record, ReportService $reports): void {
                DB::transaction(fn () => $reports->moderate($record, auth()->user()));

                Notification::make()->title('Contenu supprimé.')->success()->send();
            });
    }
}
