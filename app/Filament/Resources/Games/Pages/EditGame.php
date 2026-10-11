<?php

namespace App\Filament\Resources\Games\Pages;

use App\Filament\Resources\Games\GameResource;
use App\Models\Run;
use Filament\Actions\Action;
use Filament\Actions\DeleteAction;
use Filament\Actions\ViewAction;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\EditRecord;
use Illuminate\Support\Facades\Artisan;
use Throwable;

class EditGame extends EditRecord
{
    protected static string $resource = GameResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Action::make('resetScores')
                ->label('Réinitialiser les scores')
                ->color('danger')
                ->requiresConfirmation()
                ->modalHeading('Réinitialiser les scores du jeu')
                ->modalDescription('Toutes les parties de ce jeu seront supprimées. Cette action est irréversible.')
                ->action(function (): void {
                    try {
                        Artisan::call('kado:reset-scores', [
                            'gameId' => $this->record->id,
                        ]);

                        Notification::make()
                            ->title('Scores réinitialisés.')
                            ->success()
                            ->send();
                    } catch (Throwable $exception) {
                        report($exception);

                        Notification::make()
                            ->title('Impossible de réinitialiser les scores.')
                            ->body('Consultez les logs pour plus de détails, puis réessayez.')
                            ->danger()
                            ->send();
                    }
                }),
            Action::make('deleteReplays')
                ->label('Supprimer les replays')
                ->color('danger')
                ->requiresConfirmation()
                ->modalHeading('Supprimer les replays du jeu')
                ->modalDescription('Tous les replays de ce jeu seront supprimés. Cette action est irréversible.')
                ->action(function (): void {
                    try {
                        Run::where('game_id', $this->record->id)->update(['replay' => null]);

                        Notification::make()
                            ->title('Replays supprimés.')
                            ->success()
                            ->send();
                    } catch (Throwable $exception) {
                        report($exception);

                        Notification::make()
                            ->title('Impossible de supprimer les replays.')
                            ->body('Consultez les logs pour plus de détails, puis réessayez.')
                            ->danger()
                            ->send();
                    }
                }),
            ViewAction::make(),
            DeleteAction::make(),
        ];
    }
}
