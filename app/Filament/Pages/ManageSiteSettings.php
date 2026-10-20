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
                Section::make('Parties')
                    ->columns(3)
                    ->schema([
                        TextInput::make('games_per_day')
                            ->label('Parties par jour')
                            ->helperText('Données à chaque joueur tous les jours à minuit. -1 ou 0 : illimitées.')
                            ->numeric()
                            ->integer()
                            ->minValue(-1)
                            ->required(),
                        TextInput::make('runs_max_concurrency')
                            ->label('Parties en même temps')
                            ->helperText('Parties qu\'un joueur peut avoir en cours à la fois. -1 : illimitées.')
                            ->numeric()
                            ->integer()
                            ->minValue(-1)
                            ->required(),
                        TextInput::make('runs_open_minutes')
                            ->label('Durée d\'une partie en cours')
                            ->helperText('Après ce temps, une partie pas terminée (onglet fermé) ne compte plus dans les parties en même temps.')
                            ->numeric()
                            ->integer()
                            ->minValue(1)
                            ->required()
                            ->suffix('minutes'),
                    ]),
                Section::make('Fonctionnalités')
                    ->schema([
                        Toggle::make('achievements_enabled')
                            ->label('Succès')
                            ->helperText('Désactivés : aucune progression n\'est calculée et rien n\'est affiché aux joueurs (l\'administration des succès reste accessible).'),
                        Toggle::make('game_builds_enabled')
                            ->label('Rejouer les replays avec leur version du jeu')
                            ->helperText('Les anciennes versions des jeux sont archivées à chaque build (storage/app/game-builds). Désactivé : chaque replay est rejoué par la version actuelle. À laisser désactivé tant que la production vide storage/ à chaque déploiement.'),
                    ]),
                Section::make('Thèmes')
                    ->description('Prix des thèmes du site, achetés une fois avec des points Kado.')
                    ->columns(3)
                    ->schema(collect(config('kado.themes'))->except('base')->map(fn (array $theme, string $key) => TextInput::make("theme_prices.{$key}")
                        ->label($theme['name'])
                        ->numeric()
                        ->integer()
                        ->minValue(0)
                        ->required()
                        ->suffix('points kado'))->values()->all()),
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
