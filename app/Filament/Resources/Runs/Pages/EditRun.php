<?php

namespace App\Filament\Resources\Runs\Pages;

use App\Filament\Resources\Runs\RunDeletionActions;
use App\Filament\Resources\Runs\RunResource;
use Filament\Resources\Pages\EditRecord;

class EditRun extends EditRecord
{
    protected static string $resource = RunResource::class;

    protected function getHeaderActions(): array
    {
        return [
            RunDeletionActions::delete(),
        ];
    }
}
