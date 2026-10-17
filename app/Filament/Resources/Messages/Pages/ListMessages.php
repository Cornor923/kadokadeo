<?php

namespace App\Filament\Resources\Messages\Pages;

use App\Filament\Resources\Messages\MessageResource;
use App\Models\User;
use App\Services\MessageService;
use Filament\Actions\Action;
use Filament\Forms\Components\Checkbox;
use Filament\Forms\Components\Radio;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\ListRecords;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Components\Utilities\Get;
use Filament\Schemas\Components\View;
use Filament\Support\Icons\Heroicon;

class ListMessages extends ListRecords
{
    protected static string $resource = MessageResource::class;

    protected function getHeaderActions(): array
    {
        return [
            self::sendSystemMessageAction(),
        ];
    }

    // a message of the site, signed "KadoKado", to a player or to every player not banned, written in Marktwin with its
    // preview (<kado-marktwin>, resources/js/admin/marktwin.js)
    public static function sendSystemMessageAction(): Action
    {
        return Action::make('sendSystemMessage')
            ->label('Envoyer un message système')
            ->icon(Heroicon::OutlinedPaperAirplane)
            ->modalHeading('Envoyer un message signé KadoKado')
            ->modalSubmitActionLabel('Envoyer')
            ->modalWidth('3xl')
            ->schema([
                Radio::make('target')
                    ->label('Destinataires')
                    ->options(['one' => 'Un joueur', 'all' => 'Tous les joueurs'])
                    ->default('one')
                    ->inline()
                    ->live()
                    ->required(),
                Select::make('recipient_id')
                    ->label('Joueur')
                    ->searchable()
                    ->getSearchResultsUsing(fn (string $search) => User::query()
                        ->whereLike('display_name', "%{$search}%")
                        ->orderBy('display_name')
                        ->limit(50)
                        ->pluck('display_name', 'id')
                        ->all())
                    ->getOptionLabelUsing(fn ($value) => User::query()->find($value)?->display_name)
                    ->visible(fn (Get $get) => $get('target') === 'one')
                    ->required(fn (Get $get) => $get('target') === 'one'),
                Checkbox::make('confirm_all')
                    ->label(fn () => 'Je confirme l\'envoi à tous les joueurs non bannis ('.User::query()->whereNull('banned_at')->count().')')
                    ->visible(fn (Get $get) => $get('target') === 'all')
                    ->accepted(fn (Get $get) => $get('target') === 'all')
                    ->validationMessages(['accepted' => 'Cochez la case pour confirmer l\'envoi à tous les joueurs.']),
                TextInput::make('subject')
                    ->label('Sujet')
                    ->required()
                    ->maxLength(100),
                Textarea::make('body')
                    ->label('Message')
                    ->helperText('En Marktwin : **gras**, _italique_, __souligné__, ~~barré~~, ||spoiler||, [lien](https://…), [quote=pseudo]…[/quote], [ul][li]…[/li][/ul], smileys :kk-smile:, :kk-biggrin:…')
                    ->required()
                    ->maxLength(5000)
                    ->rows(8)
                    ->live(debounce: 500),
                Section::make('Aperçu')
                    ->compact()
                    ->schema([
                        View::make('filament.marktwin-preview')
                            ->viewData(fn (Get $get) => ['text' => (string) $get('body')]),
                    ]),
            ])
            ->action(function (array $data, MessageService $messages): void {
                if ($data['target'] === 'all') {
                    $count = $messages->systemToAll($data['subject'], $data['body']);
                    Notification::make()->title("Message envoyé à {$count} joueur(s).")->success()->send();

                    return;
                }
                $recipient = User::query()->findOrFail($data['recipient_id']);
                $messages->system($recipient, $data['subject'], $data['body']);
                Notification::make()->title("Message envoyé à {$recipient->display_name}.")->success()->send();
            });
    }
}
