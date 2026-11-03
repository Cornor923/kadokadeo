<?php

namespace App\Filament\Resources\Messages\Tables;

use App\Events\UnreadCountsChanged;
use App\Models\Message;
use App\Support\Realtime;
use Filament\Actions\Action;
use Filament\Actions\DeleteAction;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

// the private messages of all the players (a message deleted by a player from his box stays until both did)
class MessagesTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn (Builder $query) => $query->with(['sender', 'recipient']))
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('created_at')
                    ->label('Date')
                    ->dateTime('d/m/Y H:i')
                    ->sortable(),
                TextColumn::make('sender.display_name')
                    ->label('Expéditeur')
                    ->placeholder('KadoKado')
                    ->searchable(),
                TextColumn::make('recipient.display_name')
                    ->label('Destinataire')
                    ->searchable(),
                TextColumn::make('subject')
                    ->label('Sujet')
                    ->limit(60)
                    ->searchable(),
                IconColumn::make('read_at')
                    ->label('Lu')
                    ->state(fn (Message $record) => $record->read_at !== null)
                    ->boolean()
                    ->falseColor('gray'),
                TextColumn::make('deleted')
                    ->label('Supprimé')
                    ->state(fn (Message $record) => collect([
                        $record->sender_deleted_at ? 'par l\'expéditeur' : null,
                        $record->recipient_deleted_at ? 'par le destinataire' : null,
                    ])->filter()->join(', '))
                    ->placeholder('—'),
            ])
            ->filters([
                SelectFilter::make('type')
                    ->label('Type')
                    ->options(['system' => 'Messages du site (KadoKado)', 'players' => 'Entre joueurs'])
                    ->query(fn (Builder $query, array $data) => match ($data['value'] ?? null) {
                        'system' => $query->whereNull('sender_id'),
                        'players' => $query->whereNotNull('sender_id'),
                        default => $query,
                    }),
                SelectFilter::make('sender')
                    ->label('Expéditeur')
                    ->relationship('sender', 'display_name')
                    ->searchable(),
                SelectFilter::make('recipient')
                    ->label('Destinataire')
                    ->relationship('recipient', 'display_name')
                    ->searchable(),
            ])
            ->recordActions([
                Action::make('read')
                    ->label('Lire')
                    ->icon(Heroicon::OutlinedEye)
                    ->color('gray')
                    ->modalHeading(fn (Message $record) => $record->subject)
                    ->modalContent(fn (Message $record) => view('filament.message', ['message' => $record]))
                    ->modalSubmitAction(false)
                    ->modalCancelActionLabel('Fermer'),
                DeleteAction::make()
                    ->label('Supprimer')
                    ->modalHeading('Supprimer ce message')
                    ->modalDescription('Le message disparaît des boîtes de l\'expéditeur et du destinataire.')
                    // the badge of the recipient
                    ->after(fn (Message $record) => Realtime::send(new UnreadCountsChanged($record->recipient_id))),
            ]);
    }
}
