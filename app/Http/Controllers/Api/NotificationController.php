<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserNotificationResource;
use App\Models\UserNotification;
use App\Services\NotificationService;
use App\Support\Unread;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;

// the notifications of the player (the tab « Notifications » of his messages)
class NotificationController extends Controller implements HasMiddleware
{
    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum'),
        ];
    }

    public function __construct(private readonly NotificationService $notifications) {}

    // the last changed first (a like brings its notification back on top)
    public function index(Request $request)
    {
        $user = $request->user();
        $notifications = UserNotificationResource::eagerLoad($this->notifications->visibleOf($user))
            ->orderByDesc('updated_at')
            ->orderByDesc('id')
            ->paginate(30);

        return response()->json([
            'data' => UserNotificationResource::collection($notifications->getCollection())->resolve(),
            'meta' => ['current_page' => $notifications->currentPage(), 'last_page' => $notifications->lastPage()],
            'unread' => Unread::counts($user),
        ]);
    }

    public function unread(Request $request)
    {
        return ['data' => Unread::counts($request->user())];
    }

    public function read(Request $request)
    {
        $this->notifications->markAllRead($request->user());

        return ['data' => Unread::counts($request->user())];
    }

    public function destroy(Request $request, UserNotification $notification)
    {
        abort_unless($notification->user_id === $request->user()->id, 404);
        $this->notifications->delete($notification);

        return response()->noContent();
    }

    public function destroyAll(Request $request)
    {
        $this->notifications->deleteAll($request->user());

        return response()->noContent();
    }
}
