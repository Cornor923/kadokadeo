<?php

namespace App\Filament\Resources\Runs;

use App\Enums\AntiCheatBit;
use App\Filament\Resources\Runs\Pages\EditRun;
use App\Filament\Resources\Runs\Pages\ListRuns;
use App\Filament\Resources\Runs\Pages\ViewRun;
use App\Filament\Resources\Runs\RelationManagers\CommentsRelationManager;
use App\Filament\Resources\Runs\Schemas\RunInfolist;
use App\Models\Run;
use Filament\Forms\Components\Checkbox;
use Filament\Forms\Components\DateTimePicker;
use Filament\Forms\Components\TextInput;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletingScope;

class RunResource extends Resource
{
    protected static ?string $modelLabel = 'partie';

    protected static ?string $pluralModelLabel = 'parties';

    protected static ?string $model = Run::class;

    protected static bool $shouldRegisterNavigation = false;

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            TextInput::make('period_id')
                ->label('Période')
                ->numeric(),
            TextInput::make('user_id')
                ->label('ID utilisateur')
                ->required()
                ->numeric(),
            TextInput::make('contract_score')
                ->label('Score du contrat')
                ->numeric(),
            TextInput::make('contract_points')
                ->label('Points du contrat')
                ->numeric(),
            TextInput::make('seed')->label('Graine'),
            TextInput::make('score')
                ->label('Score')
                ->numeric(),
            TextInput::make('score_details')->label('Détails du score'),
            TextInput::make('play_time_seconds')
                ->label('Temps de jeu (s)')
                ->numeric(),
            TextInput::make('replay')->label('Replay'),
            DateTimePicker::make('completed_at')->label('Terminée le'),
            Checkbox::make('is_cheat')->label('Triche'),
            // what the game detected during the run (the `ac` mask it sent)
            TextEntry::make('anticheat_flags')
                ->label('Détections du client')
                ->state(fn (?Run $record) => $record?->anticheat_flags ? AntiCheatBit::describe($record->anticheat_flags) : 'Aucune'),
            TextEntry::make('replay_frames')
                ->label('Frames du replay')
                ->placeholder('—'),
        ]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return RunInfolist::configure($schema);
    }

    // the admin reads every run: RunPolicy::view (the replay page of the site) refuses the runs without replay
    public static function canView(Model $record): bool
    {
        return true;
    }

    // the deleted runs too (their comments, their replay)
    public static function getRecordRouteBindingEloquentQuery(): Builder
    {
        return parent::getRecordRouteBindingEloquentQuery()->withoutGlobalScopes([SoftDeletingScope::class]);
    }

    public static function getRelations(): array
    {
        return [
            'comments' => CommentsRelationManager::class,
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => ListRuns::route('/'),
            'view' => ViewRun::route('/{record}'),
            'edit' => EditRun::route('/{record}/edit'),
        ];
    }
}
