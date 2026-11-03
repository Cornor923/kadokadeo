<?php

namespace App\Filament\Pages;

use App\Enums\ClanBonusType;
use App\Services\ClanMissionPaliers;
use App\Services\ClanMissionService;
use App\Settings\ClanSettings;
use BackedEnum;
use Filament\Forms\Components\Repeater;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Pages\SettingsPage;
use Filament\Schemas\Components\Html;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Components\Utilities\Get;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Illuminate\Support\HtmlString;
use UnitEnum;

// the rules of the clans, shown as they are on the help page
class ManageClanSettings extends SettingsPage
{
    protected static string $settings = ClanSettings::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedUserGroup;

    protected static string|UnitEnum|null $navigationGroup = 'Paramètres';

    protected static ?string $navigationLabel = 'Clans';

    protected static ?string $title = 'Paramètres des clans';

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Clans')
                    ->columnSpanFull()
                    ->schema([
                        Toggle::make('enabled')
                            ->label('Activer les clans')
                            ->helperText('Désactivés, les pages des clans sont fermées aux joueurs (« Prochainement disponible ») et leurs routes refusées. L\'administration des clans reste accessible.'),
                        $this->integer('max_members', 'Nombre maximum de membres', min: 1),
                        $this->integer('creation_price', 'Prix de création d\'un clan (points Kado)')
                            ->helperText('0 : gratuit.'),
                        $this->integer('application_price', 'Prix d\'une candidature (points Kado)')
                            ->helperText('Payé à chaque candidature (un joueur peut postuler dans plusieurs clans à la fois). Remboursé si le clan la refuse, si le joueur la retire, ou quand un autre clan l\'accepte.'),
                    ]),

                Section::make('Attaques et défenses')
                    ->description('Les missions sont gratuites et illimitées. Les attaques et les défenses utilisent les parties du jour, puis les parties de clan achetées avec des points Kado.')
                    ->columns(2)
                    ->columnSpanFull()
                    ->schema([
                        $this->integer('attack_games_per_day', 'Parties d\'attaque et de défense par jour')
                            ->helperText('Données à chaque joueur tous les jours (remise à zéro quotidienne des parties).'),
                        $this->integer('attack_hours', 'Durée d\'une attaque (heures)', min: 1)
                            ->helperText('Le temps qu\'a le clan attaqué pour battre le score.'),
                        $this->integer('attack_max_points', 'Points maximum d\'une attaque réussie', min: 1)
                            ->helperText('Contre un clan qui a autant de points ou plus. Un point de moins par palier (écart maximum / points maximum) que le clan attaqué a en dessous de l\'attaquant.'),
                        $this->integer('protection_range', 'Écart de score maximum', min: 1)
                            ->helperText('Les clans plus éloignés sont protégés des attaques.'),
                        $this->share('attacker_seats_share', 'Part des sièges « Attaquant »'),
                        $this->share('defender_seats_share', 'Part des sièges « Défenseur »'),
                    ]),

                Section::make('Missions')
                    ->columns(2)
                    ->columnSpanFull()
                    ->schema([
                        $this->integer('mission_hours', 'Durée de la première mission (heures)', min: 1)->live(onBlur: true),
                        $this->integer('mission_more_time_hours', 'Heures ajoutées par « Plus de temps »', min: 1),
                        $this->integer('mission_minutes_less', 'Temps (en minutes) en moins à chaque mission réalisée')
                            ->helperText('0 : toutes les missions durent autant que la première.')
                            ->live(onBlur: true),
                        $this->integer('mission_min_minutes', 'Temps minimum d\'une mission (minutes)', min: 1)
                            ->helperText('720 : 12 heures.')
                            ->live(onBlur: true),
                        $this->integer('mission_steps_base', 'Étapes pour un joueur seul', min: 1)->live(onBlur: true),
                        $this->decimal('mission_steps_per_member', 'Étapes en plus par membre')
                            ->helperText('0,38 : 24 étapes pour 50 membres.')
                            ->live(onBlur: true),
                        $this->integer('mission_steps_max', 'Étapes maximum', min: 1)->live(onBlur: true),
                        $this->integer('mission_steps_min', 'Étapes minimum', min: 1)->live(onBlur: true),
                        $this->decimal('mission_steps_ratio', 'Coefficient des étapes par mission')
                            ->helperText('1 : autant d\'étapes à chaque mission. En dessous de 1, moins d\'étapes à chaque nouvelle mission.')
                            ->live(onBlur: true),
                        $this->integer('mission_points_first', 'Points d\'une mission réussie', min: 1),
                        $this->integer('mission_points_every', 'Un point de moins toutes les N missions', min: 1),
                        $this->integer('mission_points_min', 'Points minimum d\'une mission réussie'),
                    ]),

                Section::make('Scores des missions')
                    ->description('La difficulté d\'une étape se compte en étoiles du jeu : de la ½ étoile verte à la rouge, puis au-delà vers le « Score 1500 » du jeu (s\'il est renseigné). La rouge pleine (son score exact) compte comme une étoile : le palier le plus haut y reste le temps d\'une étoile de progression avant d\'aller au-delà. Une part des étapes est au palier le plus haut de la mission, les autres sont réparties du palier le plus bas (la ½ étoile verte, un peu plus à chaque mission) jusqu\'à lui : chaque mission garde des étapes faciles. Les étapes sont mélangées.')
                    ->columns(2)
                    ->columnSpanFull()
                    ->schema([
                        $this->decimal('mission_stars_per_mission', 'Progression du palier le plus haut (étoiles par mission)')
                            ->helperText('Depuis la ½ étoile verte : 0,25 = une étoile toutes les 4 missions.')
                            ->live(onBlur: true),
                        $this->share('mission_beyond_last_star', 'Au-delà de l\'étoile rouge : progression par mission')
                            ->helperText('Part de l\'écart entre l\'étoile rouge et le « Score 1500 » du jeu (0,1 = 10 % par mission, 0 : rien au-delà de la rouge).')
                            ->live(onBlur: true),
                        $this->decimal('mission_bottom_per_mission', 'Progression du palier le plus bas (étoiles par mission)')
                            ->helperText('Depuis la ½ étoile verte : 0,025 = un quart d\'étoile en 10 missions.')
                            ->live(onBlur: true),
                        $this->decimal('mission_bottom_max', 'Palier le plus bas maximum (en étoiles)')
                            ->helperText('0,75 : les ¾ de l\'étoile verte. 1 : plus aucune étape grise une fois atteint.')
                            ->live(onBlur: true),
                        $this->share('mission_hard_share_min', 'Part des étapes au palier le plus haut (au départ)')->live(onBlur: true),
                        $this->share('mission_hard_share_step', 'Part en plus à chaque mission')->live(onBlur: true),
                        $this->share('mission_hard_share_max', 'Part maximum au palier le plus haut')->live(onBlur: true),
                        // what the settings give, before saving them
                        Html::make(fn (Get $get) => new HtmlString(view('filament.clan-missions-preview', $this->preview($get))->render()))
                            ->columnSpanFull(),
                    ]),

                Section::make('Options de départ')
                    ->description('Les options données à chaque clan au début de la période, la première fois qu\'il joue. Un changement compte pour les clans qui n\'ont pas encore joué de la période.')
                    ->columns(3)
                    ->columnSpanFull()
                    ->schema(collect(ClanBonusType::cases())->map(fn (ClanBonusType $type) => $this->integer("starting_bonuses.{$type->value}", "« {$type->getLabel()} »"))->all()),

                Section::make('Options des missions')
                    ->description('Les chances de gagner une option avec chaque mission réussie.')
                    ->columns(3)
                    ->columnSpanFull()
                    ->schema([
                        $this->share('bonus_chance', 'Chance de gagner une option par mission réussie'),
                        ...collect(ClanBonusType::cases())->map(fn (ClanBonusType $type) => $this->integer("bonus_weights.{$type->value}", "Poids de « {$type->getLabel()} »"))->all(),
                    ]),

                Section::make('Parties de clan')
                    ->description('Les lots de parties d\'attaque et de défense achetés avec des points Kado.')
                    ->columnSpanFull()
                    ->schema([
                        Repeater::make('game_packs')
                            ->label('Lots')
                            ->schema([
                                $this->integer('count', 'Parties', min: 1),
                                $this->integer('price', 'Prix en points Kado', min: 1),
                            ])
                            ->columns(2)
                            ->addActionLabel('Ajouter un lot'),
                    ]),

                Section::make('Récompenses de fin de période')
                    ->description('Points Kado partagés entre les membres, selon la position du clan : jusqu\'à la position indiquée (incluse), depuis la ligne précédente.')
                    ->columns(2)
                    ->columnSpanFull()
                    ->schema([
                        $this->rewards('war_rewards', 'Classement des attaques'),
                        $this->rewards('mission_rewards', 'Classement des missions'),
                    ]),
            ]);
    }

    // a mission every half star of the top difficulty, until it stops going up, for a clan of 10 members
    private function preview(Get $get): array
    {
        $values = collect(['mission_stars_per_mission', 'mission_beyond_last_star', 'mission_hard_share_min', 'mission_hard_share_step',
            'mission_hard_share_max', 'mission_steps_base', 'mission_steps_per_member', 'mission_steps_max', 'mission_steps_min',
            'mission_steps_ratio', 'mission_bottom_per_mission', 'mission_bottom_max', 'mission_hours', 'mission_minutes_less', 'mission_min_minutes'])
            ->mapWithKeys(fn (string $name) => [$name => (float) str_replace(',', '.', (string) $get($name))])
            ->all();
        $paliers = ClanMissionPaliers::fromArray($values);
        $members = 10;
        // a game at most by step (ClanMissionService::pickGames)
        $games = app(ClanMissionService::class)->missionGames()->count();
        $base = min($values['mission_steps_max'], $values['mission_steps_base'] + ($members - 1) * $values['mission_steps_per_member']);

        $rows = [];
        $stride = $paliers->starsPerMission > 0 ? max(1, (int) round(ClanMissionPaliers::START / $paliers->starsPerMission)) : 1;
        for ($number = 1; count($rows) < 25; $number += $stride) {
            $wanted = max((int) $values['mission_steps_min'], (int) round($base * $values['mission_steps_ratio'] ** ($number - 1)));
            $steps = min($wanted, $games);
            $top = $paliers->topDifficulty($number);
            $minutes = ClanMissionService::minutesOf($number, (int) $values['mission_hours'], (int) $values['mission_minutes_less'], (int) $values['mission_min_minutes']);
            $rows[] = [
                'number' => $number,
                // "23 h 50"
                'duration' => intdiv($minutes, 60).' h'.($minutes % 60 ? ' '.str_pad((string) ($minutes % 60), 2, '0', STR_PAD_LEFT) : ''),
                'top' => ClanMissionPaliers::label($top),
                'steps_count' => $steps,
                // "2 × orange", the easiest first
                'steps' => collect($paliers->levels($number, $steps))->map(fn (float $level) => ClanMissionPaliers::label($level))->countBy()
                    ->map(fn (int $count, string $label) => "{$count} × {$label}")
                    ->values()->all(),
            ];
            if ($top >= $paliers->maxDifficulty() - 1e-9 || $paliers->starsPerMission <= 0) {
                break;
            }
        }

        return ['rows' => $rows, 'members' => $members, 'games' => $games];
    }

    private function integer(string $name, string $label, int $min = 0): TextInput
    {
        return TextInput::make($name)->label($label)->required()->integer()->minValue($min);
    }

    private function decimal(string $name, string $label): TextInput
    {
        return TextInput::make($name)->label($label)->required()->numeric()->minValue(0)->step(0.001);
    }

    // 0 to 1
    private function share(string $name, string $label): TextInput
    {
        return $this->decimal($name, $label)->maxValue(1)->helperText('Entre 0 et 1 (0,2 = 20 %).');
    }

    private function rewards(string $name, string $label): Repeater
    {
        return Repeater::make($name)
            ->label($label)
            ->schema([
                $this->integer('last_rank', 'Jusqu\'à la position', min: 1),
                $this->integer('points', 'Points Kado'),
            ])
            ->columns(2)
            ->addActionLabel('Ajouter une ligne');
    }
}
