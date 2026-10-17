<?php

namespace App\Filament\Resources\Users\Schemas;

use Filament\Forms\Components\DateTimePicker;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Schema;

class UserForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('etwin_id')
                    ->label('ID Eternaltwin')
                    ->required(),
                TextInput::make('display_name')
                    ->label('Pseudo')
                    ->required(),
                TextInput::make('kado_points')
                    ->label('Kadopoints')
                    ->required()
                    ->numeric()
                    ->default(0),
                TextInput::make('kado_games')
                    ->label('Jeux kado')
                    ->required()
                    ->numeric(),
                TextInput::make('clan_attack_games')
                    ->label('Parties d\'attaque de clan du jour')
                    ->required()
                    ->integer()
                    ->minValue(0)
                    ->default(0),
                TextInput::make('clan_games')
                    ->label('Parties de clan achetées')
                    ->required()
                    ->integer()
                    ->minValue(0)
                    ->default(0),
                TextInput::make('email')
                    ->label('Adresse e-mail')
                    ->email(),
                TextInput::make('password')
                    ->label('Mot de passe')
                    ->password()
                    ->dehydrated(fn ($state) => filled($state)),
                DateTimePicker::make('last_seen_at')->label('Dernière visite'),
                Toggle::make('is_admin')
                    ->label('Administrateur')
                    ->required(),
            ]);
    }
}
