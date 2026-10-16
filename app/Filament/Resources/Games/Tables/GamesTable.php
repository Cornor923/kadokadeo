<?php

namespace App\Filament\Resources\Games\Tables;

use App\Models\Game;
use Filament\Actions\BulkAction;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Actions\ViewAction;
use Filament\Notifications\Notification;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Collection;

class GamesTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                ImageColumn::make('image_path')
                    ->label('Image')
                    ->state(fn ($record) => config('app.url').$record->image_path)
                    ->checkFileExistence(false),
                TextColumn::make('name')
                    ->label('Nom')
                    ->searchable(),
                TextColumn::make('category_id')
                    ->label('Catégorie')
                    ->getStateUsing(fn ($record) => $record->category?->name ?? 'Sans catégorie'),
                IconColumn::make('is_active')
                    ->label('Actif')
                    ->boolean(),
                IconColumn::make('is_arkadeo')
                    ->label('Jeu Arkadéo')
                    ->boolean(),
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
            ])
            ->filters([
                //
            ])
            ->recordActions([
                ViewAction::make(),
                EditAction::make(),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    self::setAttributeBulkAction('activate', 'Activer', Heroicon::OutlinedCheckCircle, 'is_active', true, 'Jeux activés.'),
                    self::setAttributeBulkAction('deactivate', 'Désactiver', Heroicon::OutlinedXCircle, 'is_active', false, 'Jeux désactivés.'),
                    self::setAttributeBulkAction('markArkadeo', 'Jeu Arkadéo', Heroicon::OutlinedStar, 'is_arkadeo', true, 'Jeux marqués Arkadéo.'),
                    self::setAttributeBulkAction('unmarkArkadeo', 'Jeu non Arkadéo', Heroicon::OutlinedMinusCircle, 'is_arkadeo', false, 'Jeux marqués non Arkadéo.'),
                    DeleteBulkAction::make(),
                ]),
            ]);
    }

    private static function setAttributeBulkAction(string $name, string $label, Heroicon $icon, string $attribute, bool $value, string $notification): BulkAction
    {
        return BulkAction::make($name)
            ->label($label)
            ->icon($icon)
            ->requiresConfirmation()
            ->deselectRecordsAfterCompletion()
            ->action(function (Collection $records) use ($attribute, $value, $notification): void {
                $records->each(fn (Game $game) => $game->update([$attribute => $value]));

                Notification::make()->title($notification)->success()->send();
            });
    }
}
