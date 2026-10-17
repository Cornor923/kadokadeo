<?php

namespace App\Filament\Resources\Clans\RelationManagers;

use App\Enums\ClanBonusType;
use App\Models\ClanBonus;
use App\Models\Period;
use Filament\Actions\CreateAction;
use Filament\Actions\DeleteAction;
use Filament\Forms\Components\Select;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;

// the options of the missions of the clan (ClanMissionService::useBonus): given or taken back by an admin
class BonusesRelationManager extends RelationManager
{
    protected static string $relationship = 'bonuses';

    protected static ?string $title = 'Options';

    protected static ?string $modelLabel = 'option';

    protected static ?string $pluralModelLabel = 'options';

    public function isReadOnly(): bool
    {
        return false;
    }

    private static function periods(): array
    {
        return Period::query()->orderByDesc('id')->limit(30)->pluck('id', 'id')->map(fn ($id) => "Période {$id}")->all();
    }

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                Select::make('type')
                    ->label('Option')
                    ->options(ClanBonusType::class)
                    ->required(),
                Select::make('period_id')
                    ->label('Période')
                    ->helperText('Les options ne servent que pendant leur période.')
                    ->options(fn () => self::periods())
                    ->default(fn () => Period::current()->value('id'))
                    ->required(),
            ]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn ($query) => $query->with('mission'))
            ->defaultSort('id', 'desc')
            ->columns([
                ImageColumn::make('icon')
                    ->label('')
                    ->state(fn (ClanBonus $record) => url($record->type->icon()))
                    ->imageHeight(28),
                TextColumn::make('type')
                    ->label('Option'),
                TextColumn::make('period_id')
                    ->label('Période')
                    ->sortable(),
                TextColumn::make('mission.number')
                    ->label('Gagnée avec la mission')
                    ->formatStateUsing(fn ($state) => "n° {$state}")
                    ->placeholder('—'),
                TextColumn::make('used_at')
                    ->label('Utilisée le')
                    ->dateTime()
                    ->placeholder('Disponible'),
                TextColumn::make('created_at')
                    ->label('Donnée le')
                    ->dateTime()
                    ->sortable(),
            ])
            ->filters([
                SelectFilter::make('period_id')
                    ->label('Période')
                    ->options(fn () => self::periods())
                    ->default(fn () => Period::current()->value('id')),
                TernaryFilter::make('used_at')
                    ->label('Utilisée')
                    ->nullable(),
            ])
            ->headerActions([
                CreateAction::make()
                    ->label('Ajouter une option')
                    ->modalHeading('Ajouter une option au clan'),
            ])
            ->recordActions([
                DeleteAction::make()
                    ->modalDescription('L\'option est retirée du clan, utilisée ou non (ses effets déjà appliqués restent).'),
            ]);
    }
}
