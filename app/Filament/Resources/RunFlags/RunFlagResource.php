<?php

namespace App\Filament\Resources\RunFlags;

use App\Enums\RunFlagStatus;
use App\Filament\Resources\RunFlags\Pages\ListRunFlags;
use App\Filament\Resources\RunFlags\Tables\RunFlagsTable;
use App\Models\RunFlag;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use UnitEnum;

// the queue of the suspicious runs (App\Services\SuspicionService): an admin looks at their replay and decides
class RunFlagResource extends Resource
{
    protected static ?string $model = RunFlag::class;

    protected static ?string $modelLabel = 'run suspecte';

    protected static ?string $pluralModelLabel = 'runs suspectes';

    protected static ?string $navigationLabel = 'Runs suspectes';

    protected static string|UnitEnum|null $navigationGroup = 'Modération';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedShieldExclamation;

    public static function getNavigationBadge(): ?string
    {
        $open = RunFlag::where('status', RunFlagStatus::OPEN)->count();

        return $open > 0 ? (string) $open : null;
    }

    public static function getNavigationBadgeColor(): ?string
    {
        return 'warning';
    }

    public static function table(Table $table): Table
    {
        return RunFlagsTable::configure($table);
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function getPages(): array
    {
        return [
            'index' => ListRunFlags::route('/'),
        ];
    }
}
