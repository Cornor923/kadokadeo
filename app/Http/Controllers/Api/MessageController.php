<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\MessageResource;
use App\Models\Message;
use App\Models\User;
use App\Services\MessageService;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Validation\Rule;

// the private messages of the player (the mail of the Kalendrier)
class MessageController extends Controller implements HasMiddleware
{
    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum'),
            new Middleware('throttle:10,1', only: ['store']),
        ];
    }

    public function __construct(private readonly MessageService $messageService) {}

    public function index(Request $request)
    {
        $validated = $request->validate(['box' => ['sometimes', Rule::in(['inbox', 'sent'])]]);
        $user = $request->user();
        $sent = ($validated['box'] ?? 'inbox') === 'sent';

        $messages = Message::query()
            ->when($sent, fn ($q) => $q->sentBy($user), fn ($q) => $q->inboxOf($user))
            ->with('sender', 'recipient')
            ->latest('id')
            ->paginate(30);

        return response()->json([
            'data' => MessageResource::collection($messages->getCollection())->resolve(),
            'meta' => ['current_page' => $messages->currentPage(), 'last_page' => $messages->lastPage()],
            'unread' => $this->messageService->unreadCount($user),
        ]);
    }

    public function unread(Request $request)
    {
        return ['data' => ['unread' => $this->messageService->unreadCount($request->user())]];
    }

    public function show(Request $request, Message $message)
    {
        $user = $request->user();
        $isRecipient = $message->recipient_id === $user->id && !$message->recipient_deleted_at;
        $isSender = $message->sender_id === $user->id && !$message->sender_deleted_at;
        abort_unless($isRecipient || $isSender, 404);

        if ($isRecipient) {
            $this->messageService->markRead($message);
        }

        return ['data' => [...MessageResource::make($message->load('sender', 'recipient'))->resolve(), 'body' => $message->body]];
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'to' => ['required', 'string', 'max:255'],
            'subject' => ['required', 'string', 'max:100'],
            'body' => ['required', 'string', 'max:5000'],
        ], [
            'to.required' => 'Indiquez le destinataire.',
            'subject.required' => 'Indiquez le sujet du message.',
            'body.required' => 'Votre message est vide.',
        ]);
        $sender = $request->user();
        $recipient = User::query()->where('display_name', $validated['to'])->orWhere('etwin_id', $validated['to'])->first();

        abort_unless($recipient, 422, 'Aucun joueur ne porte ce nom.');
        abort_if($recipient->id === $sender->id, 422, 'Vous ne pouvez pas vous écrire à vous-même.');
        abort_if($recipient->isBanned(), 422, 'Ce joueur ne peut pas recevoir de message.');

        $message = $this->messageService->send($sender, $recipient, $validated['subject'], $validated['body']);

        return response()->json(['data' => ['id' => $message->id]], 201);
    }

    public function destroy(Request $request, Message $message)
    {
        $user = $request->user();
        abort_unless($message->recipient_id === $user->id || $message->sender_id === $user->id, 404);
        $this->messageService->delete($user, $message);

        return response()->noContent();
    }
}
