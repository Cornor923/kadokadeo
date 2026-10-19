<?php

namespace App\Filament\Resources\RunFlags\Tables;

use App\Enums\RunFlagRule;
use App\Enums\RunFlagStatus;
use App\Filament\Resources\Runs\RunResource;
use App\Filament\Resources\Runs\RunVerificationTable;
use App\Filament\Resources\Users\Actions\ModerationActions;
use App\Models\RunFlag;
use App\Services\RunService;
use Filament\Actions\Action;
use Filament\Actions\ActionGroup;
use Filament\Actions\BulkAction;
use Filament\Actions\BulkActionGroup;
use Filament\Notifications\Notification;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\Filter;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;

class RunFlagsTable
{
    private const SEVERITIES = [1 => 'Faible', 2 => 'Moyenne', 3 => 'Forte'];

    public static function configure(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn (Builder $query) => $query->with(['run', 'user', 'game']))
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('created_at')
                    ->label('Date')
                    ->dateTime('d/m/Y H:i')
                    ->sortable(),
                TextColumn::make('game.name')
                    ->label('Jeu'),
                TextColumn::make('user.display_name')
                    ->label('Joueur')
                    ->searchable(),
                TextColumn::make('run.score')
                    ->label('Score')
                    ->numeric(locale: 'fr'),
                TextColumn::make('rule')
                    ->label('Règle')
                    ->badge(),
                TextColumn::make('severity')
                    ->label('Gravité')
                    ->badge()
                    ->formatStateUsing(fn (int $state) => self::SEVERITIES[$state] ?? (string) $state)
                    ->color(fn (int $state) => match ($state) {
                        3 => 'danger',
                        2 => 'warning',
                        default => 'gray',
                    })
                    ->sortable(),
                TextColumn::make('details')
                    ->label('Détails')
                    ->state(fn (RunFlag $record) => $record->rule->describe($record->details))
                    ->limit(60)
                    ->tooltip(fn (RunFlag $record) => $record->rule->describe($record->details))
                    ->wrap(),
                TextColumn::make('status')
                    ->label('Statut')
                    ->badge(),
                IconColumn::make('run.is_cheat')
                    ->label('Triche')
                    ->boolean()
                    ->trueColor('danger')
                    ->falseIcon(null),
            ])
            ->filters([
                SelectFilter::make('status')
                    ->label('Statut')
                    ->options(RunFlagStatus::class)
                    ->default(RunFlagStatus::OPEN->value),
                SelectFilter::make('rule')
                    ->label('Règle')
                    ->options(RunFlagRule::class),
                SelectFilter::make('game')
                    ->label('Jeu')
                    ->relationship('game', 'name'),
                Filter::make('not_cheat')
                    ->label('Masquer les parties déjà marquées comme triche')
                    ->default()
                    ->query(fn (Builder $query) => $query->whereHas('run', fn (Builder $run) => $run->where('is_cheat', false))),
            ])
            ->recordActions([
                RunVerificationTable::replayAction(fn (RunFlag $record) => $record->run),
                ActionGroup::make([
                    Action::make('openRun')
                        ->label('Voir la partie')
                        ->icon(Heroicon::OutlinedEye)
                        ->url(fn (RunFlag $record) => RunResource::getUrl('view', ['record' => $record->run_id])),
                    RunVerificationTable::action(fn (RunFlag $record) => $record->run),
                    self::dismissAction(),
                    self::confirmAction(),
                    ModerationActions::ban(fn (RunFlag $record) => $record->user),
                ]),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    BulkAction::make('dismiss')
                        ->label('Classer sans suite')
                        ->icon(Heroicon::OutlinedCheck)
                        ->requiresConfirmation()
                        ->action(function (Collection $records): void {
                            $records->each(fn (RunFlag $flag) => self::review($flag, RunFlagStatus::DISMISSED));

                            Notification::make()->title('Signalements classés sans suite.')->success()->send();
                        }),
                ]),
            ]);
    }

    private static function review(RunFlag $flag, RunFlagStatus $status): void
    {
        $flag->update(['status' => $status, 'reviewed_by' => auth()->id(), 'reviewed_at' => now()]);
    }

    private static function dismissAction(): Action
    {
        return Action::make('dismiss')
            ->label('Classer sans suite')
            ->icon(Heroicon::OutlinedCheck)
            ->color('gray')
            ->visible(fn (RunFlag $record) => $record->status === RunFlagStatus::OPEN)
            ->action(function (RunFlag $record): void {
                self::review($record, RunFlagStatus::DISMISSED);

                Notification::make()->title('Signalement classé sans suite.')->success()->send();
            });
    }

    private static function confirmAction(): Action
    {
        return Action::make('confirmCheat')
            ->label('Confirmer la triche')
            ->icon(Heroicon::OutlinedShieldExclamation)
            ->color('danger')
            ->visible(fn (RunFlag $record) => $record->status !== RunFlagStatus::CONFIRMED)
            ->requiresConfirmation()
            ->modalHeading('Confirmer la triche')
            ->modalDescription('La partie est marquée comme triche : retirée des classements, ses kadopoints de contrat repris.')
            ->modalSubmitActionLabel('Confirmer')
            ->action(function (RunFlag $record, RunService $runService): void {
                $runService->flagAsCheat($record->run);
                $record->run->flags()->each(fn (RunFlag $flag) => self::review($flag, RunFlagStatus::CONFIRMED));

                Notification::make()->title('Partie marquée comme triche.')->success()->send();
            });
    }
}
