<?php

namespace App\Filament\Resources\Games\RelationManagers;

use App\Enums\AchievementCategory;
use App\Enums\AchievementProgressScope;
use App\Filament\Concerns\WarnsWhenAchievementsDisabled;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\CreateAction;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Repeater;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;

class AchievementsRelationManager extends RelationManager
{
    use WarnsWhenAchievementsDisabled;

    protected static string $relationship = 'achievements';

    protected static ?string $title = 'Succès';

    protected static ?string $modelLabel = 'succès';

    protected static ?string $pluralModelLabel = 'succès';

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('key')
                    ->label('Clé')
                    ->required()
                    ->maxLength(96),
                Select::make('category')
                    ->label('Catégorie')
                    ->options(AchievementCategory::class)
                    ->required(),
                Select::make('progress_scope')
                    ->label('Progression')
                    ->options(AchievementProgressScope::class)
                    ->required(),
                Toggle::make('is_active')
                    ->label('Actif')
                    ->required(),
                Repeater::make('levels')
                    ->label('Paliers')
                    ->relationship('levels')
                    ->schema([
                        TextInput::make('level')
                            ->label('Palier')
                            ->required()
                            ->numeric()
                            ->minValue(1),
                        TextInput::make('target')
                            ->label('Objectif')
                            ->required()
                            ->numeric()
                            ->minValue(1),
                        TextInput::make('reward')
                            ->label('Récompense (kadopoints)')
                            ->required()
                            ->numeric()
                            ->minValue(0),
                        TextInput::make('title')
                            ->label('Titre')
                            ->maxLength(255),
                        Textarea::make('description')
                            ->label('Description')
                            ->columnSpanFull(),
                    ])
                    ->columns(2)
                    ->defaultItems(0)
                    ->reorderable(false)
                    ->collapsible()
                    ->itemLabel(fn (?array $state): ?string => isset($state['level']) ? 'Palier '.$state['level'] : null)
                    ->columnSpanFull(),
            ]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->recordTitleAttribute('key')
            ->description(fn () => static::achievementsDisabledNotice())
            ->columns([
                ImageColumn::make('level_icons')
                    ->label('Icônes')
                    ->state(fn ($record) => $record->levels
                        ->map(fn ($level) => $level->icon)
                        ->filter()
                        ->values()
                        ->all()
                    )
                    ->square()
                    ->checkFileExistence(false),
                TextColumn::make('id')
                    ->label('ID')
                    ->sortable(),
                TextColumn::make('key')
                    ->label('Clé')
                    ->searchable()
                    ->sortable(),
                TextColumn::make('category')
                    ->label('Catégorie')
                    ->sortable(),
                TextColumn::make('progress_scope')
                    ->label('Progression')
                    ->sortable(),
                TextColumn::make('levels_count')
                    ->label('Paliers')
                    ->counts('levels')
                    ->sortable(),
                IconColumn::make('is_active')
                    ->label('Actif')
                    ->boolean()
                    ->sortable(),
                TextColumn::make('created_at')
                    ->label('Créé le')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('updated_at')
                    ->label('Modifié le')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                SelectFilter::make('category')
                    ->label('Catégorie')
                    ->options(AchievementCategory::class),
                SelectFilter::make('progress_scope')
                    ->label('Progression')
                    ->options(AchievementProgressScope::class),
                TernaryFilter::make('is_active')
                    ->label('Actif'),
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
            ]);
    }
}
