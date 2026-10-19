<?php

namespace App\Filament\Resources\Runs\Schemas;

use App\Enums\AntiCheatBit;
use App\Filament\Resources\Games\GameResource;
use App\Filament\Resources\Users\UserResource;
use App\Models\Run;
use Filament\Infolists\Components\IconEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Components\View;
use Filament\Schemas\Schema;

// the page of a run in the admin (App\Filament\Resources\Runs\Pages\ViewRun): what it is, then its replay
class RunInfolist
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Partie')
                    ->columns(3)
                    ->columnSpanFull()
                    ->schema([
                        TextEntry::make('user.display_name')
                            ->label('Joueur')
                            ->placeholder('Ancien joueur')
                            ->url(fn (Run $record) => $record->user_id ? UserResource::getUrl('edit', ['record' => $record->user_id]) : null),
                        TextEntry::make('game.name')
                            ->label('Jeu')
                            ->url(fn (Run $record) => GameResource::getUrl('view', ['record' => $record->game_id])),
                        TextEntry::make('score')
                            ->label('Score')
                            ->numeric(locale: 'fr'),
                        TextEntry::make('contract_score')
                            ->label('Score du contrat')
                            ->numeric(locale: 'fr'),
                        TextEntry::make('contract_points')
                            ->label('Points du contrat')
                            ->numeric(locale: 'fr'),
                        TextEntry::make('play_time_seconds')
                            ->label('Temps de jeu')
                            ->formatStateUsing(fn (?int $state) => $state === null ? null : sprintf('%d min %02d s', intdiv($state, 60), $state % 60))
                            ->placeholder('—'),
                        TextEntry::make('period_id')
                            ->label('Période')
                            ->placeholder('—'),
                        TextEntry::make('league.name')
                            ->label('Ligue')
                            ->placeholder('—'),
                        TextEntry::make('completed_at')
                            ->label('Terminée le')
                            ->dateTime('d/m/Y H:i:s')
                            ->placeholder('Pas terminée'),
                        TextEntry::make('seed')
                            ->label('Graine')
                            ->placeholder('—')
                            ->copyable(),
                        TextEntry::make('id')
                            ->label('ID')
                            ->copyable(),
                        TextEntry::make('deleted_at')
                            ->label('Supprimée le')
                            ->dateTime('d/m/Y H:i')
                            ->visible(fn (Run $record) => $record->trashed()),
                    ]),

                Section::make('Anti-triche')
                    ->columns(3)
                    ->columnSpanFull()
                    ->schema([
                        IconEntry::make('is_cheat')
                            ->label('Triche')
                            ->boolean()
                            ->trueColor('danger')
                            ->falseColor('success'),
                        TextEntry::make('verification')
                            ->label('Vérification du replay')
                            ->badge()
                            ->placeholder('—'),
                        TextEntry::make('verified_at')
                            ->label('Vérifiée le')
                            ->dateTime('d/m/Y H:i')
                            ->placeholder('—'),
                        // what the game detected during the run (the `ac` mask it sent)
                        TextEntry::make('anticheat_flags')
                            ->label('Détections du client')
                            ->state(fn (Run $record) => $record->anticheat_flags ? AntiCheatBit::describe($record->anticheat_flags) : 'Aucune')
                            ->columnSpan(2),
                        TextEntry::make('replay_frames')
                            ->label('Frames du replay')
                            ->numeric(locale: 'fr')
                            ->placeholder('—'),
                    ]),

                Section::make('Replay')
                    ->columns(2)
                    ->columnSpanFull()
                    ->schema([
                        TextEntry::make('views_count')
                            ->label('Vues')
                            ->numeric(locale: 'fr'),
                        TextEntry::make('comments_count')
                            ->label('Commentaires')
                            ->numeric(locale: 'fr'),
                        View::make('filament.replay-modal')
                            ->viewData(fn (Run $record) => ['url' => route('filament.admin.runs.replay', $record->id)])
                            ->visible(fn (Run $record) => $record->completed_at !== null && $record->has_replay)
                            ->columnSpanFull(),
                    ]),
            ]);
    }
}
