<?php

namespace App\Filament\Pages;

use App\Settings\ReplaySettings;
use BackedEnum;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Pages\SettingsPage;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use UnitEnum;

// the comments and the views of the replays (App\Settings\ReplaySettings)
class ManageReplaySettings extends SettingsPage
{
    protected static string $settings = ReplaySettings::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedChatBubbleLeftRight;

    protected static string|UnitEnum|null $navigationGroup = 'Paramètres';

    protected static ?string $navigationLabel = 'Replays';

    protected static ?string $title = 'Paramètres des replays';

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Commentaires')
                    ->description('Commentaires posés à un moment du replay, affichés dans sa barre de progression.')
                    ->columns(2)
                    ->columnSpanFull()
                    ->schema([
                        Toggle::make('comments_enabled')
                            ->label('Commentaires ouverts')
                            ->helperText('Fermés, les commentaires restent affichés mais personne ne peut en écrire.')
                            ->columnSpanFull(),
                        TextInput::make('comment_max_length')
                            ->label('Longueur maximum d\'un commentaire')
                            ->required()
                            ->integer()
                            ->minValue(1)
                            ->maxValue(1000)
                            ->suffix('caractères'),
                        TextInput::make('comments_max_per_run')
                            ->label('Commentaires maximum par replay')
                            ->helperText('Réponses comprises. Tous sont chargés d\'un coup avec le replay.')
                            ->required()
                            ->integer()
                            ->minValue(0),
                        TextInput::make('comments_max_per_user_per_run')
                            ->label('Commentaires maximum d\'un joueur sur un replay')
                            ->helperText('Réponses et commentaires supprimés compris (anti-spam).')
                            ->required()
                            ->integer()
                            ->minValue(0),
                    ]),

                Section::make('Vues')
                    ->columnSpanFull()
                    ->schema([
                        TextInput::make('view_after_seconds')
                            ->label('Lecture avant de compter une vue')
                            ->helperText('Secondes de replay réellement lues (pas en pause, onglet visible). Une seule vue par joueur, le joueur de la partie n\'est pas compté.')
                            ->required()
                            ->integer()
                            ->minValue(0)
                            ->suffix('secondes'),
                    ]),
            ]);
    }
}
