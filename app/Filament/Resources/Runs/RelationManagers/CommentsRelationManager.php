<?php

namespace App\Filament\Resources\Runs\RelationManagers;

use App\Enums\ReportStatus;
use App\Filament\Resources\Users\Actions\ModerationActions;
use App\Models\RunComment;
use App\Services\RunCommentService;
use Filament\Actions\Action;
use Filament\Actions\ActionGroup;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Textarea;
use Filament\Notifications\Notification;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\TrashedFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletingScope;

// the comments of the replay of a run (App\Services\RunCommentService): the admin edits, deletes and restores them
class CommentsRelationManager extends RelationManager
{
    protected static string $relationship = 'comments';

    protected static ?string $title = 'Commentaires';

    protected static ?string $modelLabel = 'commentaire';

    protected static ?string $pluralModelLabel = 'commentaires';

    // shown on the view page too (read-only by default)
    public function isReadOnly(): bool
    {
        return false;
    }

    public static function getBadge(Model $ownerRecord, string $pageClass): ?string
    {
        return $ownerRecord->comments_count > 0 ? (string) $ownerRecord->comments_count : null;
    }

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                Textarea::make('content')
                    ->label('Commentaire')
                    ->required()
                    ->rows(3)
                    ->maxLength(fn () => app(RunCommentService::class)->maxLength())
                    ->columnSpanFull(),
            ]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn (Builder $query) => $query
                ->withoutGlobalScopes([SoftDeletingScope::class])
                ->with(['user', 'parent'])
                ->withCount(['reports as open_reports_count' => fn (Builder $reports) => $reports->where('status', ReportStatus::OPEN)]))
            ->defaultSort('frame')
            ->columns([
                TextColumn::make('frame')
                    ->label('Moment')
                    ->formatStateUsing(fn (RunComment $record) => $record->timecode())
                    ->description(fn (RunComment $record) => "frame {$record->frame}")
                    ->sortable(),
                TextColumn::make('user.display_name')
                    ->label('Auteur')
                    ->placeholder('Ancien joueur')
                    ->searchable(),
                TextColumn::make('parent_id')
                    ->label('Réponse à')
                    ->formatStateUsing(fn (RunComment $record) => $record->parent ? ($record->parent->user?->display_name ?? 'Ancien joueur').' (#'.$record->parent_id.')' : null)
                    ->placeholder('—')
                    ->toggleable(),
                TextColumn::make('content')
                    ->label('Commentaire')
                    ->wrap()
                    ->searchable(),
                TextColumn::make('likes_count')
                    ->label('J\'aime')
                    ->numeric()
                    ->sortable(),
                TextColumn::make('open_reports_count')
                    ->label('Signalements')
                    ->badge()
                    ->color(fn (int $state) => $state > 0 ? 'warning' : 'gray')
                    ->sortable(),
                TextColumn::make('created_at')
                    ->label('Écrit le')
                    ->dateTime('d/m/Y H:i')
                    ->sortable(),
                TextColumn::make('edited_at')
                    ->label('Modifié le')
                    ->dateTime('d/m/Y H:i')
                    ->placeholder('—')
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('deleted_at')
                    ->label('Supprimé le')
                    ->dateTime('d/m/Y H:i')
                    ->placeholder('—')
                    ->toggleable(),
            ])
            ->filters([
                TrashedFilter::make(),
            ])
            ->recordActions([
                EditAction::make()
                    ->visible(fn (RunComment $record) => !$record->trashed())
                    ->using(fn (RunComment $record, array $data) => app(RunCommentService::class)->update(auth()->user(), $record, $data['content'])),
                ActionGroup::make([
                    Action::make('deleteComment')
                        ->label('Supprimer')
                        ->icon(Heroicon::OutlinedTrash)
                        ->color('danger')
                        ->visible(fn (RunComment $record) => !$record->trashed())
                        ->requiresConfirmation()
                        ->modalHeading('Supprimer le commentaire')
                        ->modalDescription('Le commentaire disparaît du replay (restaurable). Ses signalements ouverts sont clos.')
                        ->action(function (RunComment $record, RunCommentService $comments): void {
                            $comments->delete(auth()->user(), $record);

                            Notification::make()->title('Commentaire supprimé.')->success()->send();
                        }),
                    Action::make('restoreComment')
                        ->label('Restaurer')
                        ->icon(Heroicon::OutlinedArrowUturnLeft)
                        ->visible(fn (RunComment $record) => $record->trashed())
                        ->action(function (RunComment $record, RunCommentService $comments): void {
                            $comments->restore(auth()->user(), $record);

                            Notification::make()->title('Commentaire restauré.')->success()->send();
                        }),
                    Action::make('forceDeleteComment')
                        ->label('Supprimer définitivement')
                        ->icon(Heroicon::OutlinedXCircle)
                        ->color('danger')
                        ->visible(fn (RunComment $record) => $record->trashed())
                        ->requiresConfirmation()
                        ->modalHeading('Supprimer définitivement le commentaire')
                        ->modalDescription('Le commentaire et ses réponses sont effacés de la base.')
                        ->action(function (RunComment $record, RunCommentService $comments): void {
                            $comments->forceDelete(auth()->user(), $record);

                            Notification::make()->title('Commentaire supprimé définitivement.')->success()->send();
                        }),
                    ModerationActions::ban(fn (RunComment $record) => $record->user),
                ]),
            ]);
    }
}
