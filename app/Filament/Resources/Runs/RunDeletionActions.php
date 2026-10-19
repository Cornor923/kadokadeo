<?php

namespace App\Filament\Resources\Runs;

use App\Models\Run;
use App\Services\ModerationService;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\ForceDeleteAction;
use Filament\Actions\ForceDeleteBulkAction;
use Filament\Actions\RestoreAction;
use Filament\Actions\RestoreBulkAction;

// a run deleted (or restored) from the admin takes back (or gives back) its contract points and the stars of its
// player in its game and period (ModerationService::deleteRun / restoreRun)
class RunDeletionActions
{
    public static function delete(): DeleteAction
    {
        return DeleteAction::make()
            ->modalDescription('La partie sort des classements (restaurable), ses points de contrat sont repris et les étoiles du joueur recalculées sans elle.')
            ->using(fn (Run $record, ModerationService $moderation) => $moderation->deleteRun($record));
    }

    public static function forceDelete(): ForceDeleteAction
    {
        return ForceDeleteAction::make()
            ->modalDescription('La partie est supprimée définitivement, ses points de contrat repris et les étoiles du joueur recalculées sans elle.')
            ->using(fn (Run $record, ModerationService $moderation) => $moderation->deleteRun($record, force: true));
    }

    public static function restore(): RestoreAction
    {
        return RestoreAction::make()
            ->modalDescription('La partie revient dans les classements, avec ses étoiles et les points de contrat repris à sa suppression.')
            ->using(fn (Run $record, ModerationService $moderation) => $moderation->restoreRun($record));
    }

    // the delete, force delete and restore actions of a row
    public static function recordActions(): array
    {
        return [self::delete(), self::forceDelete(), self::restore()];
    }

    public static function bulkActions(): array
    {
        return [
            DeleteBulkAction::make()
                ->modalDescription('Les parties sortent des classements (restaurables), leurs points de contrat sont repris et les étoiles des joueurs recalculées sans elles.')
                ->using(fn (iterable $records, ModerationService $moderation) => collect($records)
                    ->reject(fn (Run $run) => $run->trashed())
                    ->each(fn (Run $run) => $moderation->deleteRun($run))),
            ForceDeleteBulkAction::make()
                ->modalDescription('Les parties sont supprimées définitivement, leurs points de contrat repris et les étoiles des joueurs recalculées sans elles.')
                ->using(fn (iterable $records, ModerationService $moderation) => collect($records)
                    ->each(fn (Run $run) => $moderation->deleteRun($run, force: true))),
            RestoreBulkAction::make()
                ->modalDescription('Les parties reviennent dans les classements, avec leurs étoiles et les points de contrat repris à leur suppression.')
                ->using(fn (iterable $records, ModerationService $moderation) => collect($records)
                    ->each(fn (Run $run) => $moderation->restoreRun($run))),
        ];
    }
}
