<?php

namespace App\Filament\Resources\Runs\Pages;

use App\Filament\Resources\Runs\RunResource;
use App\Filament\Resources\Runs\RunVerificationTable;
use Filament\Actions\EditAction;
use Filament\Resources\Pages\ViewRecord;

// a run in the admin: its details and its replay, its comments in a tab (?relation=comments)
class ViewRun extends ViewRecord
{
    protected static string $resource = RunResource::class;

    protected function getHeaderActions(): array
    {
        return [
            RunVerificationTable::action(),
            EditAction::make(),
        ];
    }

    public function hasCombinedRelationManagerTabsWithContent(): bool
    {
        return true;
    }

    public function getContentTabLabel(): ?string
    {
        return 'Détails';
    }
}
