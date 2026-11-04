<?php

namespace App\Filament\Resources\Users\RelationManagers;

use App\Filament\Resources\Runs\RunDeletionActions;
use App\Filament\Resources\Runs\RunResource;
use App\Filament\Resources\Runs\RunVerificationTable;
use App\Models\Run;
use App\Services\DailyRankingService;
use App\Services\ScoreService;
use Filament\Actions\Action;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TrashedFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\SoftDeletingScope;
use Illuminate\Support\Collection;

// the runs of a player on the daily games, to look into them: their position of the day and the points it gave
class DailyRunsRelationManager extends RelationManager
{
    protected static string $relationship = 'runs';

    protected static ?string $title = 'Jeux du jour';

    protected static ?string $modelLabel = 'partie du jeu du jour';

    protected static ?string $pluralModelLabel = 'parties du jeu du jour';

    // the rows of the page: run id => position (its ranked runs only)
    private ?Collection $positions = null;

    public function table(Table $table): Table
    {
        return $table
            ->recordTitleAttribute('id')
            ->defaultSort('daily_game_id', 'desc')
            ->columns([
                TextColumn::make('dailyGame.day')
                    ->label('Jour')
                    ->date('d/m/Y'),
                TextColumn::make('game.name')
                    ->label('Jeu'),
                TextColumn::make('score')
                    ->label('Score')
                    ->numeric()
                    ->sortable(),
                TextColumn::make('position')
                    ->label('Position')
                    ->state(fn (Run $record) => $this->position($record))
                    ->placeholder('—'),
                TextColumn::make('ranking_points')
                    ->label('Points de classement')
                    ->state(function (Run $record) {
                        $position = $this->position($record);

                        return $position ? DailyRankingService::pointsForPosition($position) : null;
                    })
                    ->placeholder('—'),
                TextColumn::make('contract_score')
                    ->label('Score du contrat')
                    ->numeric(),
                TextColumn::make('contract_points')
                    ->label('Points du contrat')
                    ->numeric(),
                IconColumn::make('contract_done')
                    ->label('Contrat réussi')
                    ->boolean()
                    ->state(fn (Run $record) => $record->score !== null && $record->score >= $record->contract_score),
                TextColumn::make('play_time_seconds')
                    ->label('Temps de jeu (s)')
                    ->numeric()
                    ->sortable(),
                TextColumn::make('period_id')
                    ->label('Période')
                    ->numeric()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('completed_at')
                    ->label('Terminée le')
                    ->dateTime('d/m/Y H:i')
                    ->sortable(),
                TextColumn::make('deleted_at')
                    ->label('Supprimé le')
                    ->dateTime('d/m/Y H:i')
                    ->toggleable(isToggledHiddenByDefault: true),
                ...RunVerificationTable::columns(),
            ])
            ->filters([
                SelectFilter::make('period_id')
                    ->label('Période')
                    ->relationship('period', 'id'),
                TrashedFilter::make(),
                RunVerificationTable::filter(),
            ])
            ->recordUrl(fn (Run $record) => RunResource::getUrl('view', ['record' => $record]))
            ->recordActions([
                Action::make('view')
                    ->label('Voir')
                    ->icon(Heroicon::OutlinedEye)
                    ->color('gray')
                    ->url(fn (Run $record) => RunResource::getUrl('view', ['record' => $record])),
                RunVerificationTable::replayAction(),
                RunVerificationTable::action(),
                ...RunDeletionActions::recordActions(),
            ])
            ->modifyQueryUsing(fn (Builder $query) => $query
                ->whereNotNull('daily_game_id')
                ->with(['dailyGame', 'game', 'user'])
                ->withoutGlobalScopes([
                    SoftDeletingScope::class,
                ]));
    }

    // null: not ranked (a cheat, a deleted run, another run of the player was better)
    private function position(Run $run): ?int
    {
        $this->positions ??= app(ScoreService::class)
            ->rankedDailyRuns($this->getTableRecords()->pluck('daily_game_id')->unique()->values()->all())
            ->where('user_id', $run->user_id)
            ->pluck('rank_position', 'id');

        return $this->positions[$run->id] ?? null;
    }
}
