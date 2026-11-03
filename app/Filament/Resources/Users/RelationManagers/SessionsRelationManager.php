<?php

namespace App\Filament\Resources\Users\RelationManagers;

use App\Models\Session;
use App\Models\User;
use Filament\Actions\Action;
use Filament\Notifications\Notification;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

// the browsers where the player is logged in (the sessions of the site), and their logout from all of them
class SessionsRelationManager extends RelationManager
{
    protected static string $relationship = 'sessions';

    protected static ?string $title = 'Sessions';

    protected static ?string $modelLabel = 'session';

    protected static ?string $pluralModelLabel = 'sessions';

    public function isReadOnly(): bool
    {
        return true;
    }

    public function table(Table $table): Table
    {
        return $table
            ->recordTitleAttribute('id')
            ->description('Les navigateurs où le joueur est connecté. Une session expirée est rouverte à sa prochaine visite tant que son cookie « se souvenir de moi » est valable : « Déconnecter partout » les ferme toutes.')
            ->defaultSort('last_activity', 'desc')
            ->columns([
                TextColumn::make('device')
                    ->label('Appareil')
                    ->state(fn (Session $record): string => $record->device()),
                TextColumn::make('ip_address')
                    ->label('Adresse IP')
                    ->placeholder('-')
                    ->copyable()
                    ->searchable(),
                TextColumn::make('last_activity')
                    ->label('Dernière activité')
                    ->formatStateUsing(fn (Session $record): string => $record->lastActivityAt()->diffForHumans())
                    ->tooltip(fn (Session $record): string => $record->lastActivityAt()->format('d/m/Y H:i:s'))
                    ->sortable(),
                TextColumn::make('state')
                    ->label('État')
                    ->badge()
                    ->state(fn (Session $record): string => match (true) {
                        $record->id === session()->getId() => 'Votre session',
                        $record->isActive() => 'Active',
                        default => 'Expirée',
                    })
                    ->color(fn (string $state): string => match ($state) {
                        'Expirée' => 'gray',
                        default => 'success',
                    }),
                TextColumn::make('user_agent')
                    ->label('User agent')
                    ->placeholder('-')
                    ->wrap()
                    ->searchable()
                    ->toggleable(),
            ])
            ->headerActions([
                Action::make('logOutEverywhere')
                    ->label('Déconnecter partout')
                    ->icon(Heroicon::OutlinedArrowRightStartOnRectangle)
                    ->color('danger')
                    ->requiresConfirmation()
                    ->modalHeading('Déconnecter le joueur partout ?')
                    ->modalDescription('Ses sessions sont fermées et son cookie « se souvenir de moi » ne vaut plus rien : il devra se reconnecter avec Eternaltwin sur chacun de ses appareils.')
                    ->modalSubmitActionLabel('Déconnecter')
                    ->action(function (): void {
                        /** @var User $user */
                        $user = $this->getOwnerRecord();
                        $user->logOutEverywhere();
                        Notification::make()
                            ->title('Le joueur est déconnecté de tous ses appareils.')
                            ->success()
                            ->send();
                    }),
            ]);
    }
}
