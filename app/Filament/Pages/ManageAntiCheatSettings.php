<?php

namespace App\Filament\Pages;

use App\Enums\AntiCheatBit;
use App\Models\Game;
use App\Services\ReplayVerifier;
use App\Settings\AntiCheatSettings;
use BackedEnum;
use Filament\Forms\Components\CheckboxList;
use Filament\Forms\Components\KeyValue;
use Filament\Forms\Components\Repeater;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Pages\SettingsPage;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use UnitEnum;

// the anti cheat (App\Settings\AntiCheatSettings): what marks a run as cheated, the queue of the suspicious runs, the
// replay verifier and its analyzers of the moves
class ManageAntiCheatSettings extends SettingsPage
{
    protected static string $settings = AntiCheatSettings::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedShieldExclamation;

    protected static string|UnitEnum|null $navigationGroup = 'Paramètres';

    protected static ?string $navigationLabel = 'Anti-triche';

    protected static ?string $title = 'Paramètres de l\'anti-triche';

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Exigences des replays')
                    ->description('Hors partie du jour, un replay sans ces informations vient d\'un jeu modifié : la partie est marquée comme triche. À activer un ou deux jours après le déploiement des jeux qui les enregistrent (les pages ouvertes avant ont l\'ancienne version).')
                    ->columnSpanFull()
                    ->schema([
                        Toggle::make('require_rng_stir')
                            ->label('Exiger le mélange des tirages')
                            ->helperText('Les tirages mélangés par les frames et les actions du joueur.'),
                        Toggle::make('require_input_phases')
                            ->label('Exiger le moment des actions')
                            ->helperText('Le moment des actions du joueur dans leur frame (replay version 4).'),
                    ]),

                Section::make('Détections du jeu')
                    ->description('Ce que le jeu a détecté pendant la partie. Une détection ni « à examiner » ni « ignorée » marque la partie comme triche.')
                    ->columns(2)
                    ->columnSpanFull()
                    ->schema([
                        $this->bits('soft_bits', 'À examiner')
                            ->helperText('La partie n\'est pas marquée comme triche, elle va dans « Runs suspectes ».'),
                        $this->bits('ignored_bits', 'Ignorées')
                            ->helperText('Seulement gardées sur la partie (l\'emportent sur « À examiner »). Les fonctions du navigateur modifiées et les actions générées par un script arrivent sur la plupart des navigateurs mobiles.'),
                    ]),

                Section::make('Runs suspectes')
                    ->description('Chaque partie terminée est évaluée pour la file « Modération > Runs suspectes ». Rien n\'est sanctionné automatiquement.')
                    ->columns(2)
                    ->columnSpanFull()
                    ->schema([
                        Toggle::make('suspicion_enabled')
                            ->label('Évaluer les parties')
                            ->columnSpanFull(),
                        Toggle::make('suspicion_world_record')
                            ->label('Signaler un nouveau record du jeu')
                            ->helperText('Un score élevé seul n\'est pas signalé (trop de parties légitimes).')
                            ->columnSpanFull(),
                        $this->integer('suspicion_game_min_runs', 'Parties terminées du jeu avant de signaler ses records')
                            ->helperText('Les premiers records d\'un jeu ne veulent rien dire.'),
                        $this->decimal('suspicion_wall_clock_tolerance', 'Tolérance sur le temps réel')
                            ->helperText('Le replay (32 frames par seconde) ne peut pas durer plus que le temps de la partie sur le serveur, à cette part près (0,02 = 2 %).'),
                        $this->integer('suspicion_wall_clock_margin_seconds', 'Marge sur le temps réel')
                            ->suffix('secondes'),
                        Toggle::make('suspicion_slow_motion')
                            ->label('Signaler les ralentis')
                            ->helperText('Bien moins de frames que le temps de la partie. Le temps passé sur les écrans d\'intro et de contrat compte aussi : désactivé par défaut.')
                            ->columnSpanFull(),
                        $this->decimal('suspicion_slow_ratio', 'Rapport frames / temps réel en dessous duquel c\'est un ralenti'),
                        $this->integer('suspicion_slow_min_seconds', 'Écart minimum pour un ralenti')
                            ->suffix('secondes'),
                    ]),

                Section::make('Vérificateur de replays')
                    ->description('Les replays des parties qui comptent (meilleur score, contrat, partie du jour, clan) sont rejoués sur le serveur pour vérifier leur score. Node et Chrome : variables KADO_REPLAY_VERIFIER_NODE / _BROWSER du serveur, diagnostic dans « Paramètres > Vérificateur de replays ».')
                    ->columns(2)
                    ->columnSpanFull()
                    ->schema([
                        Toggle::make('verifier_enabled')
                            ->label('Vérifier les replays')
                            ->columnSpanFull(),
                        $this->integer('verifier_timeout', 'Durée maximum d\'une vérification', min: 10)
                            ->suffix('secondes'),
                        Select::make('verifier_untrusted_games')
                            ->label('Jeux non fiables')
                            ->helperText('Leur replay finit parfois autrement que la partie (bug de déterminisme) : un score différent est signalé, pas sanctionné.')
                            ->multiple()
                            ->searchable()
                            ->options(fn () => $this->gameOptions()),
                    ]),

                Section::make('Analyse des coups')
                    ->description('Les analyseurs d\'un jeu (resources/js/replay-verifier/analyzers/<jeu>.mjs) regardent si les coups du replay ressemblent à ceux d\'un joueur ou d\'un solveur. Calibrer leurs seuils (php artisan kado:replays:analyze <jeu>) avant d\'activer le signalement.')
                    ->columns(2)
                    ->columnSpanFull()
                    ->schema([
                        Toggle::make('analysis_enabled')
                            ->label('Analyser les coups')
                            ->helperText('Le résultat est gardé avec la vérification.'),
                        Toggle::make('analysis_flag')
                            ->label('Signaler les parties suspectes')
                            ->helperText('Une analyse suspecte envoie la partie dans « Runs suspectes ».'),
                        $this->decimal('analysis_sample_rate', 'Part des autres parties vérifiées pour leur analyse')
                            ->maxValue(1)
                            ->helperText('Des jeux qui ont un analyseur, parmi celles qui ne sont pas vérifiées sinon. Entre 0 et 1 (0,1 = 10 %).'),
                        Repeater::make('analysis_games')
                            ->label('Seuils des analyseurs')
                            ->helperText('Un jeu sans ligne prend les valeurs par défaut de son analyseur. Les valeurs numériques et true / false sont converties.')
                            ->schema([
                                Select::make('game')
                                    ->label('Jeu')
                                    ->options(fn () => $this->analyzerOptions())
                                    ->required()
                                    ->distinct(),
                                KeyValue::make('params')
                                    ->label('Paramètres')
                                    ->keyLabel('Paramètre')
                                    ->valueLabel('Valeur')
                                    ->addActionLabel('Ajouter un paramètre'),
                            ])
                            ->itemLabel(fn (array $state) => $this->analyzerOptions()[$state['game'] ?? ''] ?? null)
                            ->addActionLabel('Ajouter un jeu')
                            ->collapsible()
                            ->columnSpanFull(),
                    ]),
            ]);
    }

    private const BIT_MASKS = ['soft_bits', 'ignored_bits'];

    // the masks of App\Enums\AntiCheatBit as their checked boxes (strings: the values of the checkboxes in the page)
    protected function mutateFormDataBeforeFill(array $data): array
    {
        foreach (self::BIT_MASKS as $name) {
            $data[$name] = array_map(fn (AntiCheatBit $bit) => (string) $bit->value, AntiCheatBit::in((int) $data[$name]));
        }

        return $data;
    }

    protected function mutateFormDataBeforeSave(array $data): array
    {
        foreach (self::BIT_MASKS as $name) {
            $data[$name] = array_reduce((array) $data[$name], fn (int $mask, $bit) => $mask | (int) $bit, 0);
        }

        return $data;
    }

    private function bits(string $name, string $label): CheckboxList
    {
        return CheckboxList::make($name)
            ->label($label)
            ->options(collect(AntiCheatBit::cases())->mapWithKeys(fn (AntiCheatBit $bit) => [$bit->value => $bit->getLabel()]));
    }

    private function integer(string $name, string $label, int $min = 0): TextInput
    {
        return TextInput::make($name)->label($label)->required()->integer()->minValue($min);
    }

    private function decimal(string $name, string $label): TextInput
    {
        return TextInput::make($name)->label($label)->required()->numeric()->minValue(0)->step(0.01);
    }

    /**
     * @return array<string, string> [game_key => name]
     */
    private function gameOptions(): array
    {
        return Game::query()->orderBy('name')->get()->mapWithKeys(fn (Game $game) => [$game->game_key => $game->name])->all();
    }

    /**
     * The games with an analyzer of the moves.
     *
     * @return array<string, string> [game_key => name]
     */
    private function analyzerOptions(): array
    {
        return once(function () {
            $names = $this->gameOptions();

            return collect(ReplayVerifier::analyzerKeys())->mapWithKeys(fn (string $key) => [$key => $names[$key] ?? $key])->all();
        });
    }
}
