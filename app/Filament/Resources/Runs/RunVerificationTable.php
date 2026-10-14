<?php

namespace App\Filament\Resources\Runs;

use App\Enums\RunVerification;
use App\Jobs\VerifyRunReplay;
use App\Models\Run;
use Closure;
use Filament\Actions\Action;
use Filament\Notifications\Notification;
use Filament\Support\Enums\Width;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;

// the replay of a run played again on the server (App\Jobs\VerifyRunReplay), in the tables of runs
class RunVerificationTable
{
    public static function columns(): array
    {
        return [
            IconColumn::make('is_cheat')
                ->label('Triche')
                ->boolean()
                ->trueColor('danger')
                ->falseIcon(null)
                ->toggleable(),
            TextColumn::make('verification')
                ->label('Vérification')
                ->badge()
                ->placeholder('—')
                ->tooltip(fn (Run $record) => $record->verified_at ? 'Le '.$record->verified_at->format('d/m/Y H:i') : null)
                ->toggleable(),
        ];
    }

    public static function filter(): SelectFilter
    {
        return SelectFilter::make('verification')
            ->label('Vérification')
            ->options(RunVerification::class);
    }

    // $run: the run of a record of the table (by default the record)
    public static function action(?Closure $run = null): Action
    {
        $run ??= fn (Run $record) => $record;

        return Action::make('verifyReplay')
            ->label('Revérifier')
            ->icon(Heroicon::OutlinedShieldCheck)
            ->visible(fn ($record) => $run($record)?->completed_at !== null)
            ->requiresConfirmation()
            ->modalHeading('Revérifier la partie')
            ->modalDescription('Le replay est rejoué sur le serveur et son score comparé au score envoyé. Un score différent marque la partie comme triche.')
            ->modalSubmitActionLabel('Revérifier')
            ->action(function ($record) use ($run): void {
                $record = $run($record);
                $record->update(['verification' => RunVerification::PENDING]);
                VerifyRunReplay::dispatch($record->id);

                Notification::make()
                    ->title('Vérification lancée.')
                    ->body(config('kado.replay_verifier.enabled') ? null : 'Le vérificateur est désactivé (KADO_REPLAY_VERIFIER).')
                    ->success()
                    ->send();
            });
    }

    // the replay in a modal (App\Http\Controllers\RunReplayController); $run: as for action()
    public static function replayAction(?Closure $run = null): Action
    {
        $run ??= fn (Run $record) => $record;

        return Action::make('watchReplay')
            ->label('Voir le replay')
            ->icon(Heroicon::OutlinedPlayCircle)
            ->color('gray')
            ->visible(fn ($record) => $run($record)?->completed_at !== null)
            ->modalHeading(fn ($record) => sprintf('Replay de %s (%s) : %s points', $run($record)->user?->display_name, $run($record)->game?->name, $run($record)->score))
            ->modalContent(fn ($record) => view('filament.replay-modal', ['url' => route('filament.admin.runs.replay', $run($record)->id)]))
            ->modalWidth(Width::ThreeExtraLarge)
            ->modalSubmitAction(false)
            ->modalCancelActionLabel('Fermer');
    }
}
