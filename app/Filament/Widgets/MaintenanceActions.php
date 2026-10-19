<?php

namespace App\Filament\Widgets;

use App\Models\Achievement;
use Filament\Notifications\Notification;
use Filament\Widgets\Widget;
use Illuminate\Support\Facades\Artisan;
use Throwable;

class MaintenanceActions extends Widget
{
    protected string $view = 'filament.widgets.maintenance-actions';

    protected int|string|array $columnSpan = 'full';

    protected static ?int $sort = 3;

    public function resetScores(): void
    {
        try {
            Artisan::call('kado:reset-scores');

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
    }

    public function prepareNewPeriod(): void
    {
        try {
            Artisan::call('kado:prepare-new-period');

            Notification::make()
                ->title('Nouvelle période préparée.')
                ->success()
                ->send();
        } catch (Throwable $exception) {
            report($exception);

            Notification::make()
                ->title('Impossible de préparer une nouvelle période.')
                ->body('Une période est peut-être déjà en cours.')
                ->danger()
                ->send();
        }
    }

    public function deleteAchievements(): void
    {
        try {
            Achievement::query()->delete();
            Artisan::call('db:seed', ['--force' => true, '--class' => 'AchievementsSeeder']);

            Notification::make()
                ->title('Succès supprimés et recréés.')
                ->success()
                ->send();
        } catch (Throwable $exception) {
            report($exception);

            Notification::make()
                ->title('Impossible de supprimer les succès.')
                ->body('Consultez les logs pour plus de détails, puis réessayez.')
                ->danger()
                ->send();
        }
    }
}
