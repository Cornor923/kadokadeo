<?php

namespace App\Filament\Pages;

use App\Settings\SiteSettings;
use BackedEnum;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Pages\SettingsPage;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use UnitEnum;

class ManageSiteSettings extends SettingsPage
{
    protected static string $settings = SiteSettings::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedMegaphone;

    protected static string|UnitEnum|null $navigationGroup = 'Paramètres';

    protected static ?string $navigationLabel = 'Site';

    protected static ?string $title = 'Paramètres du site';

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Annonce')
                    ->description('Message affiché en haut de chaque page.')
                    ->schema([
                        Toggle::make('announcement_enabled')
                            ->label('Activée'),
                        Select::make('announcement_level')
                            ->label('Style')
                            ->options([
                                'error' => 'Alerte (rose)',
                                'success' => 'Information (vert)',
                            ])
                            ->required(),
                        Textarea::make('announcement_content')
                            ->label('Contenu')
                            ->helperText('Markdown inline : **gras**, *italique*, [lien](https://...). Les retours à la ligne sont conservés.')
                            ->rows(4)
                            ->maxLength(2000),
                    ]),
                Section::make('Poids plume')
                    ->description('Récompenses versées à la clôture de chaque période aux joueurs ayant des plumes (une plume par jeu dominé en ligue Paradis).')
                    ->schema([
                        TextInput::make('poids_plume_jackpot')
                            ->label('Jackpot')
                            ->helperText('Partagé à parts égales entre les joueurs ayant le plus de plumes.')
                            ->numeric()
                            ->integer()
                            ->minValue(0)
                            ->required()
                            ->suffix('points kado'),
                        TextInput::make('poids_plume_shared_pool')
                            ->label('Récompense partagée')
                            ->helperText('Partagée à parts égales entre les autres joueurs ayant au moins 2 plumes (hors gagnants du jackpot).')
                            ->numeric()
                            ->integer()
                            ->minValue(0)
                            ->required()
                            ->suffix('points kado'),
                    ]),
            ]);
    }
}
