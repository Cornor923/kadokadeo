<?php

namespace App\Filament\Resources\Runs\Pages;

use App\Filament\Resources\Runs\RunResource;
use Filament\Resources\Pages\ListRecords;
use Filament\Tables\Table;

class ListRuns extends ListRecords
{
    protected static string $resource = RunResource::class;

    protected function getHeaderActions(): array
    {
        return [
        ];
    }

    public function table(Table $table): Table
    {
        return $table;
    }
}
