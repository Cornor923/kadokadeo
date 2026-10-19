<?php

namespace App\Filament\Resources\Users\Tables;

use App\Filament\Resources\Users\Actions\ModerationActions;
use Filament\Actions\ActionGroup;
use Filament\Actions\EditAction;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;

class UsersTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('etwin_id')
                    ->label('ID Eternaltwin')
                    ->searchable(),
                TextColumn::make('display_name')
                    ->label('Pseudo')
                    ->searchable(),
                TextColumn::make('kado_points')
                    ->label('Kadopoints')
                    ->numeric()
                    ->sortable(),
                TextColumn::make('kado_games')
                    ->label('Jeux kado')
                    ->numeric()
                    ->sortable(),
                TextColumn::make('email')
                    ->label('Adresse e-mail')
                    ->searchable(),
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
                TextColumn::make('last_seen_at')
                    ->label('Dernière visite')
                    ->dateTime()
                    ->sortable(),
                IconColumn::make('is_admin')
                    ->label('Administrateur')
                    ->boolean(),
                TextColumn::make('ban_reason')
                    ->label('Banni')
                    ->badge()
                    ->color('danger')
                    ->tooltip(fn ($record) => $record->banned_at ? 'Banni le '.$record->banned_at->format('d/m/Y H:i') : null),
            ])
            ->filters([
                TernaryFilter::make('banned_at')
                    ->label('Banni')
                    ->nullable()
                    ->placeholder('Tous')
                    ->trueLabel('Bannis')
                    ->falseLabel('Non bannis'),
            ])
            // no deletion of players (UserResource): banning is the sanction
            ->recordActions([
                EditAction::make(),
                ActionGroup::make(ModerationActions::all()),
            ]);
    }
}
