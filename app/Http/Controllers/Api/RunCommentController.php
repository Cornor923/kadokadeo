<?php

namespace App\Http\Controllers\Api;

use App\Enums\ReportReason;
use App\Http\Controllers\Controller;
use App\Http\Resources\RunCommentResource;
use App\Models\Run;
use App\Models\RunComment;
use App\Services\ReportService;
use App\Services\RunCommentService;
use App\Services\RunViewService;
use App\Settings\ReplaySettings;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

// the comments of a replay (App\Services\RunCommentService), its views (App\Services\RunViewService) and the reports of
// its comments (App\Services\ReportService): for the players who can watch the replay (RunPolicy::view)
class RunCommentController extends Controller implements HasMiddleware
{
    public static function middleware()
    {
        // their own counters (the prefix): the likes do not use up the comments
        return [
            new Middleware('auth:sanctum'),
            new Middleware('throttle:10,1,run-comments', only: ['store', 'update']),
            new Middleware('throttle:60,1,run-comment-likes', only: ['like', 'unlike']),
            new Middleware('throttle:10,1,reports', only: ['report']),
            new Middleware('throttle:30,1,run-views', only: ['view']),
        ];
    }

    public function __construct(
        private readonly RunCommentService $comments,
        private readonly ReplaySettings $settings,
    ) {}

    // all the comments of the replay at once (their number is limited): the page puts their marks in the progress bar
    public function index(Request $request, Run $run)
    {
        Gate::authorize('view', $run);
        $request->attributes->set('run_comment_likes', array_flip($this->comments->likedBy($request->user(), $run)));

        return RunCommentResource::collection($this->comments->forReplay($run))->additional([
            'viewer' => ['can_comment' => $this->comments->canComment()],
            'limits' => [
                'max_length' => $this->comments->maxLength(),
                'view_after_seconds' => $this->settings->view_after_seconds,
            ],
            'report_reasons' => ReportReason::options(),
        ]);
    }

    public function store(Request $request, Run $run)
    {
        Gate::authorize('view', $run);
        $validated = $request->validate([
            'frame' => ['required', 'integer', 'min:0', 'max:2000000000'],
            'content' => ['required', 'string', 'max:'.$this->comments->maxLength()],
            'parent_id' => ['nullable', 'integer'],
        ], $this->messages());
        $parent = isset($validated['parent_id']) ? RunComment::query()->find($validated['parent_id']) : null;
        abort_if(isset($validated['parent_id']) && !$parent, 404);
        $comment = $this->comments->create($request->user(), $run, $validated['frame'], $validated['content'], $parent);

        return RunCommentResource::make($comment)->response()->setStatusCode(201);
    }

    public function update(Request $request, RunComment $comment)
    {
        $validated = $request->validate([
            'content' => ['required', 'string', 'max:'.$this->comments->maxLength()],
        ], $this->messages());
        $this->comments->update($request->user(), $comment, $validated['content']);

        return response()->noContent();
    }

    public function destroy(Request $request, RunComment $comment)
    {
        $this->comments->delete($request->user(), $comment);

        return response()->noContent();
    }

    public function like(Request $request, RunComment $comment)
    {
        return response()->json(['data' => ['liked' => true, 'likes_count' => $this->comments->like($request->user(), $comment)]]);
    }

    public function unlike(Request $request, RunComment $comment)
    {
        return response()->json(['data' => ['liked' => false, 'likes_count' => $this->comments->unlike($request->user(), $comment)]]);
    }

    public function report(Request $request, RunComment $comment, ReportService $reports)
    {
        $validated = $request->validate([
            'reason' => ['required', Rule::enum(ReportReason::class)],
            'details' => ['nullable', 'string', 'max:500'],
        ], [
            'reason.required' => 'Choisissez un motif.',
            'reason.enum' => 'Choisissez un motif.',
            'details.max' => 'Les précisions ne doivent pas dépasser 500 caractères.',
        ]);
        $reports->report($request->user(), $comment, ReportReason::from($validated['reason']), $validated['details'] ?? null);

        return response()->noContent();
    }

    // the replay watched long enough (ReplaySettings::view_after_seconds, measured by the page)
    public function view(Request $request, Run $run, RunViewService $views)
    {
        Gate::authorize('view', $run);
        $views->record($request->user(), $run);

        return response()->noContent();
    }

    private function messages(): array
    {
        return [
            'content.required' => 'Le commentaire est vide.',
            'content.max' => 'Le commentaire ne doit pas dépasser '.$this->comments->maxLength().' caractères.',
            'frame.required' => 'Le moment du replay est manquant.',
        ];
    }
}
