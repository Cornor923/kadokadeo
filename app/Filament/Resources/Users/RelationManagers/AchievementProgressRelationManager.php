<?php

namespace App\Filament\Resources\Users\RelationManagers;

use App\Filament\Concerns\WarnsWhenAchievementsDisabled;
use App\Models\Achievement;
use App\Models\Game;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\CreateAction;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\DateTimePicker;
use Filament\Forms\Components\KeyValue;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\Filter;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class AchievementProgressRelationManager extends RelationManager
{
    use WarnsWhenAchievementsDisabled;

    protected static string $relationship = 'achievementProgress';

    protected static ?string $title = 'Succès';

    protected static ?string $modelLabel = 'progression';

    protected static ?string $pluralModelLabel = 'progressions';

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                Select::make('achievement_id')
                    ->label('Succès')
                    ->options(fn () => self::achievementOptions())
                    ->searchable()
                    ->required(),
                Select::make('game_id')
                    ->label('Jeu')
                    ->options(fn () => Game::query()->orderBy('name')->pluck('name', 'id'))
                    ->searchable()
                    ->placeholder('Tous les jeux'),
                TextInput::make('period_id')
                    ->label('Période')
                    ->numeric(),
                TextInput::make('scope_key')
                    ->label('Portée')
                    ->helperText('« lifetime », ou « period:<id> » pour un succès par période')
                    ->required()
                    ->maxLength(64),
                TextInput::make('current_value')
                    ->label('Progression')
                    ->required()
                    ->numeric()
                    ->minValue(0),
                TextInput::make('completed_level')
                    ->label('Palier atteint')
                    ->required()
                    ->numeric()
                    ->minValue(0),
                DateTimePicker::make('completed_at')
                    ->label('Premier palier le'),
                KeyValue::make('state')
                    ->label('État de la règle')
                    ->columnSpanFull(),
            ]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->recordTitleAttribute('id')
            ->description(fn () => static::achievementsDisabledNotice())
            ->columns([
                TextColumn::make('id')
                    ->label('ID')
                    ->sortable(),
                TextColumn::make('achievement.key')
                    ->label('Succès')
                    ->searchable()
                    ->sortable(),
                TextColumn::make('game.name')
                    ->label('Jeu')
                    ->placeholder('Tous les jeux')
                    ->searchable()
                    ->sortable(),
                TextColumn::make('achievement.category')
                    ->label('Catégorie')
                    ->sortable(),
                TextColumn::make('achievement.progress_scope')
                    ->label('Progression')
                    ->sortable(),
                TextColumn::make('scope_key')
                    ->label('Portée')
                    ->searchable()
                    ->sortable(),
                TextColumn::make('current_value')
                    ->label('Valeur')
                    ->numeric()
                    ->sortable(),
                TextColumn::make('completed_level')
                    ->label('Palier atteint')
                    ->numeric()
                    ->sortable(),
                TextColumn::make('period_id')
                    ->label('Période')
                    ->numeric()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('state')
                    ->label('État de la règle')
                    ->formatStateUsing(fn (mixed $state): string => $state ? json_encode($state) ?: '-' : '-')
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('completed_at')
                    ->label('Premier palier le')
                    ->dateTime()
                    ->sortable(),
                TextColumn::make('updated_at')
                    ->label('Modifié le')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Filter::make('completed')
                    ->label('Avec un palier atteint')
                    ->query(fn (Builder $query): Builder => $query->where('completed_level', '>', 0)),
                SelectFilter::make('achievement_id')
                    ->label('Succès')
                    ->options(fn () => self::achievementOptions())
                    ->searchable(),
                SelectFilter::make('game_id')
                    ->label('Jeu')
                    ->options(fn () => Game::query()->orderBy('name')->pluck('name', 'id'))
                    ->searchable(),
            ])
            ->headerActions([
                CreateAction::make(),
            ])
            ->recordActions([
                EditAction::make(),
                DeleteAction::make(),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),
                ]),
            ])
            ->modifyQueryUsing(fn (Builder $query): Builder => $query->with(['achievement.game', 'game']));
    }

    private static function achievementOptions()
    {
        return Achievement::query()
            ->with('game')
            ->orderBy('key')
            ->get()
            ->mapWithKeys(fn (Achievement $achievement): array => [
                $achievement->id => ($achievement->game?->name ?? 'Tous les jeux').' / '.$achievement->key,
            ]);
    }
}
