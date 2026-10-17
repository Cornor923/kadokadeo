<?php

namespace App\Filament\Resources\Clans\RelationManagers;

use App\Exceptions\ClanException;
use App\Models\ClanMission;
use App\Models\ClanMissionStep;
use App\Models\Period;
use App\Services\ClanMissionService;
use Filament\Actions\Action;
use Filament\Notifications\Notification;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

// the missions of the clan, their steps, and "Régénérer la mission en cours" (ClanMissionService::regenerateMission)
class MissionsRelationManager extends RelationManager
{
    protected static string $relationship = 'missions';

    protected static ?string $title = 'Missions';

    protected static ?string $modelLabel = 'mission';

    protected static ?string $pluralModelLabel = 'missions';

    public const STATUSES = [
        ClanMission::ACTIVE => 'En cours',
        ClanMission::COMPLETED => 'Réussie',
        ClanMission::FAILED => 'Échouée',
        ClanMission::SKIPPED => 'Remplacée',
    ];

    public function isReadOnly(): bool
    {
        return false;
    }

    public function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn ($query) => $query->with('steps', 'bonus'))
            ->defaultSort('id', 'desc')
            ->columns([
                TextColumn::make('period_id')
                    ->label('Période')
                    ->sortable(),
                TextColumn::make('number')
                    ->label('N°')
                    ->sortable(),
                TextColumn::make('status')
                    ->label('Statut')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => self::STATUSES[$state] ?? $state)
                    ->color(fn (string $state) => match ($state) {
                        ClanMission::ACTIVE => 'info',
                        ClanMission::COMPLETED => 'success',
                        ClanMission::FAILED => 'danger',
                        default => 'gray',
                    }),
                TextColumn::make('steps_done')
                    ->label('Étapes réussies')
                    ->state(fn (ClanMission $record) => $record->steps->filter(fn (ClanMissionStep $step) => $step->isDone())->count().' / '.$record->steps->count()),
                TextColumn::make('points')
                    ->label('Points')
                    ->numeric(),
                TextColumn::make('bonus.type')
                    ->label('Option gagnée')
                    ->placeholder('—'),
                TextColumn::make('expires_at')
                    ->label('Fin')
                    ->dateTime()
                    ->sortable(),
                TextColumn::make('completed_at')
                    ->label('Réussie le')
                    ->dateTime()
                    ->placeholder('—')
                    ->toggleable(),
            ])
            ->filters([
                SelectFilter::make('period_id')
                    ->label('Période')
                    ->options(fn () => Period::query()->orderByDesc('id')->limit(30)->pluck('id', 'id')->map(fn ($id) => "Période {$id}")->all())
                    ->default(fn () => Period::current()->value('id')),
                SelectFilter::make('status')
                    ->label('Statut')
                    ->options(self::STATUSES),
            ])
            ->headerActions([
                Action::make('regenerate')
                    ->label('Régénérer la mission en cours')
                    ->icon(Heroicon::OutlinedArrowPath)
                    ->color('warning')
                    ->requiresConfirmation()
                    ->modalHeading('Régénérer la mission en cours')
                    ->modalDescription('La mission en cours est remplacée par une nouvelle mission du même numéro, avec les réglages actuels (jeux et scores tirés à nouveau). Le clan ne perd aucun point, comme avec l\'option « Mission suivante ». Les étapes déjà réussies de la mission remplacée ne comptent plus.')
                    ->modalSubmitActionLabel('Régénérer')
                    ->action(function (): void {
                        try {
                            $mission = app(ClanMissionService::class)->regenerateMission($this->getOwnerRecord());
                        } catch (ClanException $e) {
                            Notification::make()->title($e->getMessage())->danger()->send();

                            return;
                        }
                        Notification::make()->title("Nouvelle mission n° {$mission->number} : {$mission->steps->count()} étape(s).")->success()->send();
                    }),
            ])
            ->recordActions([
                Action::make('steps')
                    ->label('Étapes')
                    ->icon(Heroicon::OutlinedListBullet)
                    ->color('gray')
                    ->modalHeading(fn (ClanMission $record) => "Mission n° {$record->number} (période {$record->period_id})")
                    ->modalContent(fn (ClanMission $record) => view('filament.clan-mission-steps', [
                        'steps' => $record->steps()->with('game', 'completedBy', 'reservedBy')->get(),
                    ]))
                    ->modalSubmitAction(false)
                    ->modalCancelActionLabel('Fermer'),
            ]);
    }
}
