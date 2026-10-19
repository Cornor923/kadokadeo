<?php

namespace App\Filament\Pages;

use App\Enums\RunVerification;
use App\Filament\Resources\Runs\RunResource;
use App\Filament\Resources\Runs\RunVerificationTable;
use App\Filament\Widgets\ReplayVerificationStats;
use App\Models\ReplayVerification;
use App\Services\ReplayVerifier;
use BackedEnum;
use Filament\Actions\Action;
use Filament\Pages\Page;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Concerns\InteractsWithTable;
use Filament\Tables\Contracts\HasTable;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Support\Str;
use UnitEnum;

// the replay verifier (App\Jobs\VerifyRunReplay): its stats, the history of its verifications (App\Models\ReplayVerification),
// and whether it can run on this server: Node, the browser, its libraries, WebGL and fonts. The browser can be
// downloaded from here when the server has none.
class ReplayVerifierDashboard extends Page implements HasTable
{
    use InteractsWithTable;

    protected string $view = 'filament.pages.replay-verifier';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedShieldCheck;

    protected static string|UnitEnum|null $navigationGroup = 'Paramètres';

    protected static ?string $navigationLabel = 'Vérificateur de replays';

    protected static ?string $title = 'Vérificateur de replays';

    /** @var array<string, mixed>|null */
    public ?array $report = null;

    protected function getHeaderWidgets(): array
    {
        return [ReplayVerificationStats::class];
    }

    public function table(Table $table): Table
    {
        $run = fn (ReplayVerification $record) => $record->run;

        return $table
            ->heading('Vérifications')
            ->description('Les replays vérifiés sans problème sont gardés '.ReplayVerification::KEEP_VERIFIED_DAYS.' jours, les autres sans limite.')
            ->query(ReplayVerification::query()->with([
                'game',
                // without the replay (large): the player loads it
                'run' => fn ($query) => $query->select('id', 'user_id', 'game_id', 'score', 'completed_at')->with('user'),
            ]))
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('created_at')
                    ->label('Date')
                    ->dateTime('d/m/Y H:i:s')
                    ->sortable(),
                TextColumn::make('game.name')
                    ->label('Jeu'),
                TextColumn::make('run.user.display_name')
                    ->label('Joueur')
                    ->placeholder('—'),
                TextColumn::make('status')
                    ->label('Résultat')
                    ->badge(),
                TextColumn::make('score')
                    ->label('Score envoyé')
                    ->numeric(),
                TextColumn::make('replay_score')
                    ->label('Score du replay')
                    ->numeric()
                    ->placeholder('—'),
                TextColumn::make('duration_ms')
                    ->label('Durée')
                    ->formatStateUsing(fn (?int $state) => $state === null ? null : number_format($state / 1000, 1, ',', ' ').' s')
                    ->placeholder('—')
                    ->sortable(),
                // the analyzer of the moves of the game (resources/js/replay-verifier/analyzers)
                TextColumn::make('analysis')
                    ->label('Analyse des coups')
                    ->state(fn (ReplayVerification $record) => self::describeAnalysis($record->analysis))
                    ->color(fn (ReplayVerification $record) => ($record->analysis['suspicious'] ?? false) ? 'danger' : null)
                    ->tooltip(fn (ReplayVerification $record) => $record->analysis ? json_encode($record->analysis['metrics'] ?? $record->analysis, JSON_UNESCAPED_UNICODE) : null)
                    ->placeholder('—'),
                TextColumn::make('error')
                    ->label('Erreur')
                    ->formatStateUsing(fn (?string $state) => Str::limit($state, 120))
                    ->tooltip(fn (ReplayVerification $record) => $record->error)
                    ->wrap()
                    ->placeholder('—'),
            ])
            ->filters([
                SelectFilter::make('status')
                    ->label('Résultat')
                    ->options(RunVerification::class),
                SelectFilter::make('game')
                    ->label('Jeu')
                    ->relationship('game', 'name')
                    ->searchable()
                    ->preload(),
            ])
            ->recordActions([
                RunVerificationTable::replayAction($run),
                Action::make('run')
                    ->label('Partie')
                    ->icon(Heroicon::OutlinedArrowTopRightOnSquare)
                    ->color('gray')
                    ->url(fn (ReplayVerification $record) => RunResource::getUrl('view', ['record' => $record->run_id])),
                RunVerificationTable::action($run),
            ]);
    }

    /**
     * The verifications of the last 30 days by game: the games whose replays fail or end differently.
     *
     * @return list<array{game: string, counts: array<string, int>}>
     */
    public function perGame(): array
    {
        return ReplayVerification::with('game')
            ->where('created_at', '>=', now()->subDays(ReplayVerification::KEEP_VERIFIED_DAYS))
            ->selectRaw('game_id, status, count(*) as total')
            ->groupBy('game_id', 'status')
            ->get()
            ->groupBy('game_id')
            ->map(fn ($rows) => [
                'game' => $rows->first()->game?->name ?? '?',
                'counts' => $rows->mapWithKeys(fn ($row) => [$row->status->value => (int) $row->total])->all(),
            ])
            ->sortBy('game')
            ->values()
            ->all();
    }

    protected function getHeaderActions(): array
    {
        return [
            Action::make('diagnose')
                ->label('Lancer le diagnostic')
                ->icon(Heroicon::OutlinedPlay)
                ->action(fn (ReplayVerifier $verifier) => $this->report = $verifier->diagnose()),
            Action::make('install')
                ->label('Télécharger le navigateur')
                ->icon(Heroicon::OutlinedArrowDownTray)
                ->color('gray')
                ->requiresConfirmation()
                ->modalHeading('Télécharger le navigateur')
                ->modalDescription('Si le serveur n’a ni Chrome ni Chromium, chrome-headless-shell (environ 100 Mo) est téléchargé dans storage/app/replay-verifier/browser. Cela peut prendre une minute. La première vérification le télécharge aussi d’elle-même.')
                ->modalSubmitActionLabel('Télécharger')
                ->action(function (ReplayVerifier $verifier) {
                    set_time_limit(0);
                    $this->report = $verifier->diagnose(install: true);
                }),
        ];
    }

    /**
     * @return array<string, string|null>
     */
    public function settings(): array
    {
        return [
            'Vérificateur activé (KADO_REPLAY_VERIFIER)' => config('kado.replay_verifier.enabled') ? 'Oui' : 'Non',
            'Node (KADO_REPLAY_VERIFIER_NODE)' => config('kado.replay_verifier.node'),
            'Navigateur (KADO_REPLAY_VERIFIER_BROWSER)' => config('kado.replay_verifier.browser') ?: 'Recherche automatique',
        ];
    }

    /**
     * The results of the diagnostic: ok is null when it cannot be told.
     *
     * @return list<array{label: string, ok: ?bool, value: string, hint: ?string}>
     */
    public function checks(): array
    {
        $r = $this->report;
        if ($r === null || isset($r['error'])) {
            return [];
        }

        $major = (int) ltrim(explode('.', $r['node'] ?? '')[0], 'v');
        $checks = [
            [
                'label' => 'Node',
                'ok' => $major >= 22,
                'value' => "{$r['node']} ({$r['platform']})",
                'hint' => $major >= 22 ? null : 'Node 22 ou plus est nécessaire.',
            ],
            [
                'label' => 'Utilisateur',
                'ok' => null,
                'value' => $r['user'] ?? '?',
                'hint' => 'Le diagnostic tourne avec l’utilisateur du serveur web, les vérifications avec celui du worker de la queue.',
            ],
        ];

        $browser = $r['browser'] ?? [];
        $checks[] = isset($browser['path'])
            ? [
                'label' => 'Navigateur',
                'ok' => true,
                'value' => $browser['path'],
                'hint' => match ($browser['source']) {
                    'env' => 'Défini par KADO_REPLAY_VERIFIER_BROWSER.',
                    'system' => 'Installé sur le système.',
                    default => 'Téléchargé par le site (@puppeteer/browsers).',
                },
            ]
            : [
                'label' => 'Navigateur',
                'ok' => false,
                'value' => $browser['error'] ?? 'Introuvable',
                'hint' => 'Utilisez « Télécharger le navigateur ».',
            ];

        $missing = $r['missingLibraries'] ?? null;
        if (isset($browser['path'])) {
            $checks[] = [
                'label' => 'Bibliothèques système',
                'ok' => $missing === null ? null : $missing === [],
                'value' => match (true) {
                    $missing === null => 'Non vérifiables',
                    $missing === [] => 'Toutes présentes',
                    default => 'Manquantes : '.implode(', ', $missing),
                },
                'hint' => $missing ? 'Elles ne s’installent pas avec npm : il faut les paquets système de Chrome (Debian : libnss3, libgbm1, libatk-bridge2.0-0…) ou le paquet chromium.' : null,
            ];
        }

        $launch = $r['launch'] ?? null;
        if ($launch !== null) {
            $checks[] = [
                'label' => 'Démarrage du navigateur',
                'ok' => $launch['ok'],
                'value' => $launch['ok'] ? $launch['version'] : $launch['error'],
                'hint' => null,
            ];
        }
        if ($launch['ok'] ?? false) {
            $checks[] = [
                'label' => 'WebGL',
                'ok' => $launch['webgl'] !== null,
                'value' => $launch['webgl'] ?? 'Indisponible',
                'hint' => $launch['webgl'] === null ? 'PIXI en a besoin pour jouer les replays.' : null,
            ];
            $checks[] = [
                'label' => 'Polices',
                'ok' => $launch['fonts'],
                'value' => $launch['fonts'] ? 'Présentes' : 'Aucune police sur le système',
                'hint' => $launch['fonts'] ? null : 'PIXI plante en mesurant un texte : il faut au moins une police (Debian : fonts-liberation).',
            ];
        }

        return $checks;
    }

    // « Meilleur coup 93 % sur 42 coups (suspect) »
    private static function describeAnalysis(?array $analysis): ?string
    {
        if (!$analysis) {
            return null;
        }
        if (isset($analysis['error'])) {
            return 'Erreur : '.Str::limit($analysis['error'], 60);
        }
        $metrics = $analysis['metrics'] ?? [];
        if (!isset($metrics['optimalRate'])) {
            return ($analysis['suspicious'] ?? false) ? 'Suspect' : 'RAS';
        }

        return sprintf('Meilleur coup %d %% sur %d coups%s', round($metrics['optimalRate'] * 100), $metrics['decisions'] ?? 0, ($analysis['suspicious'] ?? false) ? ' (suspect)' : '');
    }
}
