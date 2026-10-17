<?php

namespace App\Filament\Resources\Clans\Pages;

use App\Filament\Resources\Clans\ClanResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;

class EditClan extends EditRecord
{
    protected static string $resource = ClanResource::class;

    protected function getHeaderActions(): array
    {
        return [
            DeleteAction::make()->label('Dissoudre le clan'),
        ];
    }
}
