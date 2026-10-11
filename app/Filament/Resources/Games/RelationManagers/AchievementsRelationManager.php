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

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('key')
                    ->required()
                    ->maxLength(96),
                Select::make('category')
                    ->options(self::categoryOptions())
                    ->required(),
                Select::make('progress_scope')
                    ->options(self::progressScopeOptions())
                    ->required(),
                Toggle::make('is_active')
                    ->required(),
                Repeater::make('levels')
                    ->relationship('levels')
                    ->schema([
                        TextInput::make('level')
                            ->required()
                            ->numeric()
                            ->minValue(1),
                        TextInput::make('target')
                            ->required()
                            ->numeric()
                            ->minValue(1),
                        TextInput::make('reward')
                            ->required()
                            ->numeric()
                            ->minValue(0),
                        TextInput::make('title')
                            ->maxLength(255),
                        Textarea::make('description')
                            ->columnSpanFull(),
                    ])
                    ->columns(2)
                    ->defaultItems(0)
                    ->reorderable(false)
                    ->collapsible()
                    ->itemLabel(fn (?array $state): ?string => isset($state['level']) ? 'Level '.$state['level'] : null)
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
                    ->label('Icons')
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
                    ->searchable()
                    ->sortable(),
                TextColumn::make('category')
                    ->formatStateUsing(fn (mixed $state): string => self::formatEnumState($state))
                    ->sortable(),
                TextColumn::make('progress_scope')
                    ->formatStateUsing(fn (mixed $state): string => self::formatEnumState($state))
                    ->sortable(),
                TextColumn::make('levels_count')
                    ->label('Levels')
                    ->counts('levels')
                    ->sortable(),
                IconColumn::make('is_active')
                    ->boolean()
                    ->sortable(),
                TextColumn::make('created_at')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('updated_at')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                SelectFilter::make('category')
                    ->options(self::categoryOptions()),
                SelectFilter::make('progress_scope')
                    ->options(self::progressScopeOptions()),
                TernaryFilter::make('is_active'),
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

    private static function categoryOptions(): array
    {
        return collect(AchievementCategory::cases())
            ->mapWithKeys(fn (AchievementCategory $category): array => [$category->value => self::formatOption($category->value)])
            ->all();
    }

    private static function progressScopeOptions(): array
    {
        return collect(AchievementProgressScope::cases())
            ->mapWithKeys(fn (AchievementProgressScope $scope): array => [$scope->value => self::formatOption($scope->value)])
            ->all();
    }

    private static function formatEnumState(mixed $state): string
    {
        if ($state instanceof \BackedEnum) {
            return self::formatOption((string) $state->value);
        }

        return self::formatOption($state === null ? null : (string) $state);
    }

    private static function formatOption(?string $value): string
    {
        if ($value === null || $value === '') {
            return '-';
        }

        return ucfirst(str_replace('_', ' ', $value));
    }
}
