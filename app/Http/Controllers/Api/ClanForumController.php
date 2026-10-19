<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ClanForumMessageResource;
use App\Http\Resources\ClanForumTopicResource;
use App\Models\Clan;
use App\Models\ClanForumMessage;
use App\Models\ClanForumRead;
use App\Models\ClanForumTopic;
use App\Services\ClanForumService;
use App\Services\ClanService;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;

// the private forum of a clan (App\Services\ClanForumService): only its members see it
class ClanForumController extends Controller implements HasMiddleware
{
    public const TOPICS_PER_PAGE = 30;

    public const TITLE_MAX = 100;

    public const CONTENT_MAX = 10000;

    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum'),
            new Middleware('throttle:20,1', only: ['store', 'reply', 'updateMessage']),
        ];
    }

    public function __construct(
        private readonly ClanService $clanService,
        private readonly ClanForumService $forumService,
    ) {}

    // the topics: the pinned ones ("post-it") first, then by last message. "q" searches the titles and the messages.
    public function index(Request $request, Clan $clan)
    {
        $user = $request->user();
        $this->clanService->assertMember($user, $clan);
        $validated = $request->validate(['q' => ['nullable', 'string', 'max:100']]);

        $query = $clan->forumTopics()
            ->select('clan_forum_topics.*')
            ->addSelect(['last_read_message_id' => ClanForumRead::query()
                ->select('last_read_message_id')
                ->whereColumn('topic_id', 'clan_forum_topics.id')
                ->where('user_id', $user->id)
                ->limit(1)])
            ->with(['user', 'lastMessageUser'])
            ->orderByDesc('is_pinned')
            ->orderByDesc('last_message_at')
            ->orderByDesc('id');

        // the wildcards of LIKE are removed from the search: they are searched as text everywhere else
        $search = trim(str_replace(['%', '_', '\\'], ' ', $validated['q'] ?? ''));
        if ($search !== '') {
            $query->where(fn ($query) => $query
                ->whereLike('title', "%{$search}%")
                ->orWhereHas('messages', fn ($messages) => $messages
                    ->withoutTrashed()
                    ->whereLike('content', "%{$search}%")));
        }

        return ClanForumTopicResource::collection($query->paginate(self::TOPICS_PER_PAGE))
            ->additional(['viewer' => ['can_moderate' => $this->forumService->canModerate($user, $clan)]]);
    }

    public function store(Request $request, Clan $clan)
    {
        $validated = $request->validate([
            'title' => ['required', 'string', 'min:3', 'max:'.self::TITLE_MAX],
            'content' => ['required', 'string', 'max:'.self::CONTENT_MAX],
        ], [
            'title.required' => 'Le titre est obligatoire.',
            'title.min' => 'Le titre doit faire au moins 3 caractères.',
            'title.max' => 'Le titre ne doit pas dépasser '.self::TITLE_MAX.' caractères.',
            'content.required' => 'Le message est vide.',
            'content.max' => 'Le message ne doit pas dépasser '.self::CONTENT_MAX.' caractères.',
        ]);
        $topic = $this->forumService->createTopic($request->user(), $clan, $validated['title'], $validated['content']);

        return response()->json(['data' => ['id' => $topic->id]], 201);
    }

    // a page of the messages of a topic ("page" can be "last"): the messages shown are read
    public function show(Request $request, Clan $clan, ClanForumTopic $topic)
    {
        $user = $request->user();
        $this->assertTopicOf($clan, $topic);
        $this->clanService->assertMember($user, $clan);
        $isModerator = $this->forumService->canModerate($user, $clan);

        $page = $request->query('page') === 'last' ? $topic->pages() : max(1, (int) $request->query('page', 1));
        $messages = $topic->messages()
            ->with('user')
            ->orderBy('id')
            ->paginate(ClanForumTopic::MESSAGES_PER_PAGE, ['*'], 'page', $page);
        $messages->getCollection()->each->setRelation('topic', $topic);
        if ($messages->isNotEmpty()) {
            $this->forumService->markRead($user, $topic, $messages->getCollection()->max('id'));
        }

        $request->attributes->set('forum_moderator', $isModerator);
        $request->attributes->set('forum_roles', $this->forumService->rolesOf($clan));
        $topic->load(['user', 'lastMessageUser']);

        return ClanForumMessageResource::collection($messages)->additional([
            'topic' => ClanForumTopicResource::make($topic->setAttribute('last_read_message_id', $topic->last_message_id)),
            'viewer' => [
                'can_moderate' => $isModerator,
                'can_reply' => !$topic->is_locked || $isModerator,
                'can_rename' => $isModerator || $topic->user_id === $user->id,
            ],
        ]);
    }

    public function update(Request $request, Clan $clan, ClanForumTopic $topic)
    {
        $this->assertTopicOf($clan, $topic);
        $validated = $request->validate([
            'title' => ['sometimes', 'string', 'min:3', 'max:'.self::TITLE_MAX],
            'is_pinned' => ['sometimes', 'boolean'],
            'is_locked' => ['sometimes', 'boolean'],
        ], [
            'title.min' => 'Le titre doit faire au moins 3 caractères.',
            'title.max' => 'Le titre ne doit pas dépasser '.self::TITLE_MAX.' caractères.',
        ]);
        $this->forumService->updateTopic($request->user(), $topic, $validated);

        return response()->noContent();
    }

    public function destroy(Request $request, Clan $clan, ClanForumTopic $topic)
    {
        $this->assertTopicOf($clan, $topic);
        $this->forumService->deleteTopic($request->user(), $topic);

        return response()->noContent();
    }

    // an answer: the page where it is, to show it
    public function reply(Request $request, Clan $clan, ClanForumTopic $topic)
    {
        $this->assertTopicOf($clan, $topic);
        $validated = $request->validate(['content' => ['required', 'string', 'max:'.self::CONTENT_MAX]], [
            'content.required' => 'Le message est vide.',
            'content.max' => 'Le message ne doit pas dépasser '.self::CONTENT_MAX.' caractères.',
        ]);
        $message = $this->forumService->reply($request->user(), $topic, $validated['content']);

        return response()->json(['data' => ['id' => $message->id, 'page' => $topic->refresh()->pages()]], 201);
    }

    public function updateMessage(Request $request, Clan $clan, int $message)
    {
        $message = $this->messageOf($clan, $message);
        $validated = $request->validate(['content' => ['required', 'string', 'max:'.self::CONTENT_MAX]], [
            'content.required' => 'Le message est vide.',
            'content.max' => 'Le message ne doit pas dépasser '.self::CONTENT_MAX.' caractères.',
        ]);
        $this->forumService->editMessage($request->user(), $message, $validated['content']);

        return response()->noContent();
    }

    public function destroyMessage(Request $request, Clan $clan, int $message)
    {
        $this->forumService->deleteMessage($request->user(), $this->messageOf($clan, $message));

        return response()->noContent();
    }

    public function restoreMessage(Request $request, Clan $clan, int $message)
    {
        $this->forumService->restoreMessage($request->user(), $this->messageOf($clan, $message));

        return response()->noContent();
    }

    // a topic of another clan is not found
    private function assertTopicOf(Clan $clan, ClanForumTopic $topic): void
    {
        abort_unless($topic->clan_id === $clan->id, 404);
    }

    // the deleted messages too (to restore them), of a topic of the clan
    private function messageOf(Clan $clan, int $id): ClanForumMessage
    {
        $message = ClanForumMessage::withTrashed()->with('topic.clan')->findOrFail($id);
        abort_unless($message->topic->clan_id === $clan->id, 404);

        return $message;
    }
}
