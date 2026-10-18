<?php

namespace App\Filament\Resources\Clans;

use App\Filament\Resources\Clans\Pages\EditClan;
use App\Filament\Resources\Clans\Pages\ListClans;
use App\Filament\Resources\Clans\RelationManagers\BonusesRelationManager;
use App\Filament\Resources\Clans\RelationManagers\MembersRelationManager;
use App\Filament\Resources\Clans\RelationManagers\MissionsRelationManager;
use App\Filament\Resources\Clans\Schemas\ClanForm;
use App\Filament\Resources\Clans\Tables\ClansTable;
use App\Models\Clan;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use UnitEnum;

class ClanResource extends Resource
{
    protected static ?string $modelLabel = 'clan';

    protected static ?string $pluralModelLabel = 'clans';

    protected static ?string $model = Clan::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedUserGroup;

    protected static string|UnitEnum|null $navigationGroup = 'Modération';

    public static function form(Schema $schema): Schema
    {
        return ClanForm::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return ClansTable::configure($table);
    }

    public static function getRelations(): array
    {
        return [
            MembersRelationManager::class,
            MissionsRelationManager::class,
            BonusesRelationManager::class,
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => ListClans::route('/'),
            'edit' => EditClan::route('/{record}/edit'),
        ];
    }
}
