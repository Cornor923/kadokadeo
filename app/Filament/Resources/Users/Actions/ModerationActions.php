<?php

namespace App\Filament\Resources\Users\Actions;

use App\Enums\BanReason;
use App\Models\User;
use App\Services\ModerationService;
use Closure;
use Filament\Actions\Action;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\EditRecord;
use Filament\Support\Icons\Heroicon;

class ModerationActions
{
    public static function all(): array
    {
        return [
            self::adjustKadoPoints(),
            self::adjustGames(),
            self::deleteScores(),
            self::ban(),
            self::unban(),
        ];
    }

    // added to the balance of the moment (the form shows it read-only: saved, it would erase the gains meanwhile)
    public static function adjustKadoPoints(): Action
    {
        return Action::make('adjustKadoPoints')
            ->label('Ajuster les points Kado')
            ->icon(Heroicon::OutlinedCurrencyDollar)
            ->color('gray')
            ->modalHeading(fn (User $record) => "Ajuster les points Kado de {$record->display_name}")
            ->modalDescription(fn (User $record) => "Solde actuel : {$record->kado_points} points. Le montant est ajouté au solde du moment (négatif pour retirer des points).")
            ->modalSubmitActionLabel('Ajuster')
            ->schema([
                TextInput::make('delta')
                    ->label('Points à ajouter')
                    ->helperText('Négatif pour retirer des points.')
                    ->required()
                    ->integer()
                    ->notIn([0])
                    ->validationMessages(['not_in' => 'Le montant ne peut pas être 0.']),
            ])
            ->action(function (User $record, array $data, ModerationService $moderation, $livewire): void {
                $balance = $moderation->adjustKadoPoints($record, (int) $data['delta'], auth()->user());
                self::refreshForm($livewire, $record, ['kado_points']);

                Notification::make()
                    ->title('Points Kado ajustés.')
                    ->body("Nouveau solde : {$balance} points.")
                    ->success()
                    ->send();
            });
    }

    // added to the counters of the moment, like the points
    public static function adjustGames(): Action
    {
        $delta = fn (string $name, string $label) => TextInput::make($name)
            ->label($label)
            ->integer()
            ->default(0)
            ->required();

        return Action::make('adjustGames')
            ->label('Ajuster les parties')
            ->icon(Heroicon::OutlinedPuzzlePiece)
            ->color('gray')
            ->modalHeading(fn (User $record) => "Ajuster les parties de {$record->display_name}")
            ->modalDescription(fn (User $record) => "Actuellement : {$record->kado_games} partie(s) kado, {$record->clan_games} partie(s) de clan achetée(s), {$record->clan_attack_games} partie(s) d'attaque de clan du jour. Les nombres sont ajoutés aux compteurs du moment (négatifs pour retirer des parties).")
            ->modalSubmitActionLabel('Ajuster')
            ->schema([
                $delta('kado_games', 'Parties kado à ajouter'),
                $delta('clan_games', 'Parties de clan achetées à ajouter'),
                $delta('clan_attack_games', 'Parties d\'attaque de clan du jour à ajouter'),
            ])
            ->action(function (User $record, array $data, ModerationService $moderation, $livewire): void {
                if (!$moderation->adjustGames($record, $data)) {
                    Notification::make()
                        ->title('Parties non ajustées.')
                        ->body('Un compteur deviendrait négatif.')
                        ->danger()
                        ->send();

                    return;
                }
                self::refreshForm($livewire, $record, ModerationService::GAME_COUNTERS);

                Notification::make()
                    ->title('Parties ajustées.')
                    ->success()
                    ->send();
            });
    }

    public static function deleteScores(): Action
    {
        return Action::make('deleteScores')
            ->label('Supprimer les scores')
            ->icon(Heroicon::OutlinedTrash)
            ->color('danger')
            ->requiresConfirmation()
            ->modalHeading(fn (User $record) => "Supprimer les scores de {$record->display_name}")
            ->modalDescription('Toutes les parties du joueur seront supprimées (restaurables depuis la liste de ses parties) et ses étoiles retirées.')
            ->modalSubmitActionLabel('Supprimer')
            ->action(function (User $record, ModerationService $moderation): void {
                $deleted = $moderation->deleteScores($record);

                Notification::make()
                    ->title('Scores supprimés.')
                    ->body("{$deleted} partie(s) supprimée(s).")
                    ->success()
                    ->send();
            });
    }

    // $user: the player of a record of the table (by default the record)
    public static function ban(?Closure $user = null): Action
    {
        $user ??= fn (User $record) => $record;

        return Action::make('ban')
            ->label('Bannir')
            ->icon(Heroicon::OutlinedNoSymbol)
            ->color('danger')
            ->visible(fn ($record) => ($player = $user($record)) !== null && !$player->isBanned() && !$player->is(auth()->user()))
            ->requiresConfirmation()
            ->modalHeading(fn ($record) => "Bannir {$user($record)->display_name}")
            ->modalDescription('Le joueur sera déconnecté et ne pourra plus se connecter. Toutes ses parties seront supprimées et ses étoiles retirées.')
            ->modalSubmitActionLabel('Bannir')
            ->schema([
                Select::make('reason')
                    ->label('Raison')
                    ->options(BanReason::class)
                    ->required(),
            ])
            ->action(function ($record, array $data, ModerationService $moderation) use ($user): void {
                $player = $user($record);
                $reason = $data['reason'] instanceof BanReason ? $data['reason'] : BanReason::from($data['reason']);
                $deleted = $moderation->ban($player, $reason);

                Notification::make()
                    ->title("{$player->display_name} a été banni.")
                    ->body("{$deleted} partie(s) supprimée(s).")
                    ->success()
                    ->send();
            });
    }

    public static function unban(): Action
    {
        return Action::make('unban')
            ->label('Débannir')
            ->icon(Heroicon::OutlinedCheckCircle)
            ->color('gray')
            ->visible(fn (User $record) => $record->isBanned())
            ->requiresConfirmation()
            ->modalHeading(fn (User $record) => "Débannir {$record->display_name}")
            ->modalDescription('Le joueur pourra de nouveau se connecter. Ses scores supprimés ne sont pas restaurés.')
            ->modalSubmitActionLabel('Débannir')
            ->action(function (User $record, ModerationService $moderation): void {
                $moderation->unban($record);

                Notification::make()
                    ->title("{$record->display_name} a été débanni.")
                    ->success()
                    ->send();
            });
    }

    // the edit page shows the new counters (its form is not saved)
    private static function refreshForm($livewire, User $record, array $fields): void
    {
        if ($livewire instanceof EditRecord) {
            $record->refresh();
            $livewire->refreshFormData($fields);
        }
    }
}
