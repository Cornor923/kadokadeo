<?php

namespace App\Filament\Resources\RunFlags\Pages;

use App\Enums\AntiCheatBit;
use App\Filament\AntiCheatNotices;
use App\Filament\Resources\RunFlags\RunFlagResource;
use Filament\Actions\Action;
use Filament\Resources\Pages\ListRecords;
use Filament\Support\Icons\Heroicon;

class ListRunFlags extends ListRecords
{
    protected static string $resource = RunFlagResource::class;

    protected function getHeaderActions(): array
    {
        return [
            // which detections of the game mark a run as cheated, which ones send it here (KADO_ANTICHEAT_SOFT_BITS), which
            // ones are ignored (KADO_ANTICHEAT_IGNORED_BITS)
            Action::make('detectionRules')
                ->label('Règles de détection')
                ->icon(Heroicon::OutlinedInformationCircle)
                ->color('gray')
                ->tooltip(AntiCheatNotices::detectionRules())
                ->modalHeading('Règles de détection')
                ->modalContent(fn () => view('filament.anticheat-detection-rules', [
                    'hard' => AntiCheatBit::hardCases(),
                    'soft' => AntiCheatBit::softCases(),
                    'mask' => AntiCheatBit::softMask(),
                    'ignored' => AntiCheatBit::ignoredCases(),
                    'ignoredMask' => AntiCheatBit::ignoredMask(),
                ]))
                ->modalSubmitAction(false)
                ->modalCancelActionLabel('Fermer'),
        ];
    }
}
