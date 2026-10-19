<?php

namespace App\Filament\Resources\Clans\Schemas;

use App\Models\Clan;
use App\Rules\ClanName;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Schema;

class ClanForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('name')
                    ->label('Nom')
                    ->helperText('Lettres, chiffres, espaces et - \' . ! ? (les lettres du nom sur la page du clan).')
                    ->required()
                    ->minLength(3)
                    ->maxLength(32)
                    ->dehydrateStateUsing(fn ($state) => ClanName::normalize($state))
                    ->rule(fn (?Clan $record) => new ClanName($record?->id)),
                Select::make('leader_id')
                    ->label('Chef de clan')
                    ->relationship('leader', 'display_name', fn ($query, $record) => $query->whereHas('clanMember', fn ($q) => $q->where('clan_id', $record?->id)))
                    ->searchable()
                    ->preload(),
                Toggle::make('is_recruiting')
                    ->label('Recrute'),
                // the paid clan games given by the members, distributed by the leader and the right hands
                TextInput::make('clan_games')
                    ->label('Coffre (parties de clan)')
                    ->helperText('Parties données par les membres, que le chef et ses bras droits distribuent.')
                    ->required()
                    ->integer()
                    ->minValue(0),
                Textarea::make('description')
                    ->label('Présentation')
                    ->rows(8)
                    ->columnSpanFull(),
            ]);
    }
}
