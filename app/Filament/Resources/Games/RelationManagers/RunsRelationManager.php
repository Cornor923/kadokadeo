<?php

namespace App\Filament\Resources\Games\RelationManagers;

use App\Filament\Resources\Runs\RunResource;
use App\Filament\Resources\Runs\RunVerificationTable;
use App\Models\Run;
use Filament\Actions\Action;
use Filament\Actions\AssociateAction;
use Filament\Actions\BulkAction;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\CreateAction;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\DissociateAction;
use Filament\Actions\DissociateBulkAction;
use Filament\Actions\EditAction;
use Filament\Actions\ForceDeleteAction;
use Filament\Actions\ForceDeleteBulkAction;
use Filament\Actions\RestoreAction;
use Filament\Actions\RestoreBulkAction;
use Filament\Forms\Components\Checkbox;
use Filament\Forms\Components\DatePicker;
use Filament\Forms\Components\DateTimePicker;
use Filament\Forms\Components\TextInput;
use Filament\Notifications\Notification;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\Filter;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Filters\TrashedFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\SoftDeletingScope;
use Illuminate\Support\Carbon;

class RunsRelationManager extends RelationManager
{
    protected static string $relationship = 'runs';

    protected static ?string $title = 'Parties';

    protected static ?string $modelLabel = 'partie';

    protected static ?string $pluralModelLabel = 'parties';

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('period_id')
                    ->label('Période')
                    ->numeric(),
                TextInput::make('user_id')
                    ->label('ID utilisateur')
                    ->required()
                    ->numeric(),
                TextInput::make('contract_score')
                    ->label('Score du contrat')
                    ->required()
                    ->numeric(),
                TextInput::make('contract_points')
                    ->label('Points du contrat')
                    ->required()
                    ->numeric(),
                TextInput::make('seed')->label('Graine'),
                TextInput::make('score')
                    ->label('Score')
                    ->numeric(),
                TextInput::make('score_details')->label('Détails du score'),
                TextInput::make('play_time_seconds')
                    ->label('Temps de jeu (s)')
                    ->numeric(),
                TextInput::make('replay')->label('Replay'),
                DateTimePicker::make('completed_at')->label('Terminée le'),
                Checkbox::make('is_cheat')->label('Triche'),
            ]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->recordTitleAttribute('score')
            ->columns([
                TextColumn::make('id')
                    ->label('ID')
                    ->searchable()
                    ->toggleable(),
                TextColumn::make('period_id')
                    ->label('Période')
                    ->numeric()
                    ->sortable()
                    ->toggleable(),
                TextColumn::make('user.display_name')
                    ->label('Joueur')
                    ->numeric()
                    ->sortable()
                    ->toggleable(),
                TextColumn::make('score')
                    ->label('Score')
                    ->numeric()
                    ->sortable(query: fn (Builder $query, string $direction) => $query->orderByRaw("score {$direction} NULLS LAST"))
                    ->searchable()
                    ->toggleable(),
                TextColumn::make('seed')
                    ->label('Graine')
                    ->searchable()
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('contract_score')
                    ->label('Score du contrat')
                    ->numeric()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('contract_points')
                    ->label('Points du contrat')
                    ->numeric()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('play_time_seconds')
                    ->label('Temps de jeu (s)')
                    ->numeric()
                    ->sortable()
                    ->toggleable(),
                TextColumn::make('created_at')
                    ->label('Créé le')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('updated_at')
                    ->label('Modifié le')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('completed_at')
                    ->label('Terminée le')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(),
                IconColumn::make('has_replay')
                    ->label('Replay')
                    ->boolean()
                    ->toggleable(),
                TextColumn::make('deleted_at')
                    ->label('Supprimé le')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
                ...RunVerificationTable::columns(),
            ])
            ->filters([
                TrashedFilter::make(),
                RunVerificationTable::filter(),
                Filter::make('completed_at')
                    ->default(true)
                    ->label('Parties terminées')
                    ->query(fn (Builder $query): Builder => $query->whereNotNull('completed_at')),
                Filter::make('completed_between')
                    ->label('Date de complétion')
                    ->schema([
                        DatePicker::make('from')->label('Terminée du'),
                        DatePicker::make('until')->label('Terminée au'),
                    ])
                    ->query(fn (Builder $query, array $data): Builder => $query
                        ->when($data['from'] ?? null, fn (Builder $q, $date) => $q->where('completed_at', '>=', Carbon::parse($date)->startOfDay()))
                        ->when($data['until'] ?? null, fn (Builder $q, $date) => $q->where('completed_at', '<=', Carbon::parse($date)->endOfDay())))
                    ->indicateUsing(fn (array $data): array => array_values(array_filter([
                        ($data['from'] ?? null) ? 'Terminée du '.Carbon::parse($data['from'])->format('d/m/Y') : null,
                        ($data['until'] ?? null) ? 'Terminée au '.Carbon::parse($data['until'])->format('d/m/Y') : null,
                    ]))),
                TernaryFilter::make('replay')
                    ->label('Replay')
                    ->nullable(),
            ])
            ->headerActions([
                CreateAction::make(),
                AssociateAction::make(),
            ])
            ->recordUrl(fn (Run $record) => RunResource::getUrl('view', ['record' => $record]))
            ->recordActions([
                Action::make('view')
                    ->label('Voir')
                    ->icon(Heroicon::OutlinedEye)
                    ->color('gray')
                    ->url(fn (Run $record) => RunResource::getUrl('view', ['record' => $record])),
                EditAction::make(),
                RunVerificationTable::replayAction(),
                RunVerificationTable::action(),
                DissociateAction::make(),
                DeleteAction::make(),
                ForceDeleteAction::make(),
                RestoreAction::make(),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    BulkAction::make('deleteReplays')
                        ->label('Supprimer les replays')
                        ->icon(Heroicon::OutlinedFilm)
                        ->color('danger')
                        ->requiresConfirmation()
                        ->modalHeading('Supprimer les replays')
                        ->modalDescription('Les replays des parties sélectionnées sont supprimés définitivement. Les parties et leurs scores sont conservés.')
                        ->modalSubmitActionLabel('Supprimer')
                        ->deselectRecordsAfterCompletion()
                        ->action(function (Collection $records): void {
                            $count = Run::query()->whereKey($records->modelKeys())->whereNotNull('replay')->update(['replay' => null]);

                            Notification::make()
                                ->title($count === 0 ? 'Aucun replay à supprimer.' : sprintf('%d replay(s) supprimé(s).', $count))
                                ->success()
                                ->send();
                        }),
                    DissociateBulkAction::make(),
                    DeleteBulkAction::make(),
                    ForceDeleteBulkAction::make(),
                    RestoreBulkAction::make(),
                ]),
            ])
            ->modifyQueryUsing(fn (Builder $query) => $query
                ->withoutGlobalScopes([
                    SoftDeletingScope::class,
                ]));
    }
}
