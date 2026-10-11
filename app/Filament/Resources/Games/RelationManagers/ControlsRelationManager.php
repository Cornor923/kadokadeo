<?php

namespace App\Filament\Resources\Games\RelationManagers;

use App\Enums\ControlKey;
use Filament\Actions\CreateAction;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class ControlsRelationManager extends RelationManager
{
    protected static string $relationship = 'controls';

    protected static ?string $title = 'Contrôles';

    protected static ?string $modelLabel = 'contrôle';

    protected static ?string $pluralModelLabel = 'contrôles';

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('description')->label('Description')->required(),
                TextInput::make('order')->label('Ordre')->required(),
                Select::make('keys')->label('Touches')->options(ControlKey::class)->multiple()->required(),
            ]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')
                    ->label('ID'),
                TextColumn::make('description')->label('Description'),
                TextColumn::make('order')->label('Ordre'),
                TextColumn::make('keys')
                    ->label('Touches')
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => ControlKey::from($state)->getLabel()),
            ])
            ->headerActions([
                CreateAction::make(),
            ])
            ->recordActions([
                DeleteAction::make(),
                EditAction::make(),
            ]);
    }
}
