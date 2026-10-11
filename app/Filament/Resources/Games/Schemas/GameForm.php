<?php

namespace App\Filament\Resources\Games\Schemas;

use Filament\Forms\Components\Repeater;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Schema;

class GameForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('name')
                    ->label('Nom')
                    ->required(),
                Textarea::make('description')
                    ->label('Description')
                    ->columnSpanFull(),
                Select::make('category_id')
                    ->label('Catégorie')
                    ->options(fn () => \App\Models\Category::all()->pluck('name', 'id'))
                    ->required(),
                TextInput::make('image_path')->label('Image'),
                Repeater::make('stars')->label('Étoiles')->simple(
                    TextInput::make('value')
                        ->label('Valeur')
                        ->numeric()
                        ->required(),
                )->minItems(3)->maxItems(3),
                Toggle::make('is_active')
                    ->label('Actif')
                    ->required(),
                Toggle::make('is_arkadeo')
                    ->label('Jeu Arkadéo')
                    ->required(),
                TextInput::make('score_rankv1')->label('Score 1500'),
            ]);
    }
}
